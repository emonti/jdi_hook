#!/usr/bin/env jruby1.6
# This is a jruby port of the 'trace' example provided in the JDI examples.jar 
# that comes with the Sun JDK.
#
# A few features have been added such as method argument dumps as well as 
# the --attach, --include, --method-match, and --exclude options. 
# (The --all option is replaced by --exclude)
#
# Usage:
# * jtrace.rb -h
#
# Recommend: 
# * Sun JDK 1.6+ (provides dumps of method args when possible)
# * on win32, make sure your JAVA_HOME points to the JDK instead of JRE

require 'optparse'
require 'pp'

include Java

# This hackery seems to be necessary for win32
begin
  include_class "com.sun.jdi.Bootstrap"
rescue NameError
  if home = ENV['JAVA_HOME']
    require home + "/lib/tools.jar"
    include_class "com.sun.jdi.Bootstrap"
  end
end

include_class [
  "com.sun.jdi.IncompatibleThreadStateException",
  "com.sun.jdi.VMDisconnectedException",
  "com.sun.jdi.InternalException",
  "com.sun.jdi.event.ClassPrepareEvent",
  "com.sun.jdi.event.MethodEntryEvent",
  "com.sun.jdi.event.MethodExitEvent",
  "com.sun.jdi.event.ModificationWatchpointEvent",
  "com.sun.jdi.event.StepEvent",
  "com.sun.jdi.event.ThreadDeathEvent",
  "com.sun.jdi.event.VMDeathEvent",
  "com.sun.jdi.event.VMDisconnectEvent",
  "com.sun.jdi.event.VMStartEvent",
  "com.sun.jdi.request.EventRequest",
  "com.sun.jdi.request.StepRequest",
  "java.io.IOException",
  "java.io.InputStreamReader",
  "java.lang.InterruptedException", 
  "java.util.List",
  "java.util.Map",
]


class JdiTrace
  class EventThread < java.lang.Thread
    attr_accessor :vm, :excludes, :includes, :meth_regex, :writer, 
                  :nextBaseIndent, :connected, :vmDied, :traceMap
    attr_reader :java_version

    def initialize( parent )
      $nextBaseIndent = ""
      @connected = true
      @vmDied = true
      @traceMap = java.util.HashMap.new

      super("event-handler")
      @vm = parent.vm
      @includes = parent.includes
      @excludes = parent.excludes
      @meth_regex = parent.meth_regex
      @writer = parent.writer
      @java_version = parent.java_version
    end

    # Run the event handling thread.  
    # As long as we are connected, get event sets off 
    # the queue and dispatch the events within them.
    def run()
      queue = @vm.eventQueue()
      while @connected
        begin
          eventSet = queue.remove()
          eventSet.each {|evt| handleEvent(evt) }
          eventSet.resume()
        rescue InterruptedException
          # ignore
        rescue VMDisconnectedException
          handleDisconnectedException()
          break
        end
      end
    end

    # Create the desired event requests, and enable 
    # them so that we will get events.
    # @param watchFields  Do we want to watch assignments to fields
    def setEventRequests(watchFields)
      mgr = @vm.eventRequestManager()

      # make sure we sync on thread death
      tdr = mgr.createThreadDeathRequest()
      tdr.setSuspendPolicy(EventRequest::SUSPEND_ALL)
      tdr.enable()

      exreqs = [ mgr.createMethodEntryRequest(), mgr.createMethodExitRequest() ]
      exreqs << mgr.createClassPrepareRequest() if @watchFields
      exreqs.each do |req|
        do_class_filters(req)
        req.setSuspendPolicy(EventRequest::SUSPEND_ALL)
        req.enable()
      end
    end

    # This class keeps context on events in one thread.
    # In this implementation, context is the indentation prefix.
    class ThreadTrace 
      attr_accessor :thread, :baseIndent, :threadDelta, :indent
      attr_reader   :vm, :writer, :parent

      def initialize(thread, parent)
        @thread = thread
        @parent = parent
        @writer = parent.writer
        @java_version = parent.java_version
        @vm = parent.vm
        @meth_regex = parent.meth_regex
        @baseIndent = $nextBaseIndent.dup
        @threadDelta = "                     "
        @indent = @baseIndent.dup
        $nextBaseIndent += @threadDelta
        println("====== " + thread.name() + " ======")
      end

      def println(str)
        @writer.puts "#{@indent}#{str}"
      end

      def methodEntryEvent(event)
        meth = event.method
        meth_name = "#{meth.declaringType.name}.#{meth.name}"
        if @meth_regex.nil? or @meth_regex.match(meth_name)
          if @java_version >= "1.6"
            begin
              arg = thread.frame(0).getArgumentValues().to_a.map do |x| 
                (x.nil?)? "null" : x
              end
            rescue InternalException => exc
              arg = ["ERR: #{exc}"]
            rescue IncompatibleThreadStateException
              arg = ["ERR: got IncompatibleThreadStateException"]
            end
          else
            arg = meth.argumentTypeNames()
          end

          println("#{meth_name}(#{arg.join(', ')})")
        end
        @indent += "| "
      end

      def methodExitEvent(event)
        @indent = @indent[0..-3]
      end

      def fieldWatchEvent(event)
        println("    #{event.field.name} = #{event.valueToBe}")
      end

      # step to exception catch
      def stepEvent(event)
        @indent = @baseIndent
        begin 
          cnt = thread.frameCount 
        rescue IncompatibleThreadStateException
          cnt = 0 
        end
        0.upto(cnt) {|x| @indent += "| "}
        mgr = @vm.eventRequestManager()
        mgr.deleteEventRequest(event.request())
      end

      def threadDeathEvent(event)
        @indent = @baseIndent
        println("====== " + @thread.name() + " end ======") if @thread
      end
    end

    # Returns the ThreadTrace instance for the specified thread,
    # creating one if needed.
    def threadTrace(thread)
      if (trace = @traceMap.get(thread)).nil?
        trace = ThreadTrace.new(thread, self)
        @traceMap.put(thread, trace)
      end
      return trace
    end
   

    # Dispatch incoming events
    def handleEvent(event)
      case event
      when ModificationWatchpointEvent  : fieldWatchEvent(event)
      when MethodEntryEvent             : methodEntryEvent(event)
      when MethodExitEvent              : methodExitEvent(event)
      when StepEvent                    : stepEvent(event)
      when ThreadDeathEvent             : threadDeathEvent(event)
      when ClassPrepareEvent            : classPrepareEvent(event)
      when VMStartEvent                 : vmStartEvent(event)
      when VMDeathEvent                 : vmDeathEvent(event)
      when VMDisconnectEvent            : vmDisconnectEvent(event)
      else
        raise "Unexpected event type #{event.java_class}"
      end
    end
    
   
    # A VMDisconnectedException has happened while dealing with
    # another event. We need to flush the event queue, dealing only
    # with exit events (VMDeath, VMDisconnect) so that we terminate
    # correctly.
    def handleDisconnectedException
      queue = @vm.eventQueue()
      while @connected
        begin
          eventSet = queue.remove()
          eventSet.each do |event|
            if VMDeathEvent === event
              vmDeathEvent(event)
            elsif VMDisconnectEvent === event
              vmDisconnectEvent(event)
            end
          end
        rescue InterruptedException
          # ignore
        end
      end
    end

    def vmStartEvent(event)
      @writer.puts("-- VM Started --")
    end

    # Forward these events for thread specific processing

    def methodEntryEvent(event)
      threadTrace(event.thread()).methodEntryEvent(event)
    end

    def methodExitEvent(event)
      threadTrace(event.thread()).methodExitEvent(event)
    end

    def fieldWatchEvent(event)
      threadTrace(event.thread()).fieldWatchEvent(event)
    end

    def threadDeathEvent(event)
      if trace = @traceMap.get(event.thread())
        trace.threadDeathEvent(event)
      end
    end

    # A new class has been loaded
    # Set watchpoints on each of its fields
    def classPrepareEvent(event)
      mgr = @vm.eventRequestManager
      event.referenceType.visibleFields().each do |field|
        req = mgr.createModificationWatchpointRequest(field)
        do_class_filters(req)
        req.setSuspendPolicy(EventRequest::SUSPEND_NONE)
        req.enable()
      end
    end

    # adds class inclusion and or exclusion filters to a given 
    # event request
    def do_class_filters(req)
      if @excludes
        @excludes.each do |e| 
#          pp ["Adding Exclusion Filter:", req.java_object, e]
          req.addClassExclusionFilter(e) 
        end
      end
      if @includes
        @includes.each do |i| 
#          pp ["Adding Inclusion Filter:", req.java_object, i]
          req.addClassFilter(i)
        end
      end
    end

    def vmDeathEvent(event)
      @vmDied = true
      @writer.puts("-- The application exited --")
    end

    def vmDisconnectEvent(event)
      @connected = false
      @writer.puts("-- The application has been disconnected --") unless @vmDied
    end
  end

  class StreamRedirectThread < java.lang.Thread
    BUFFER_SIZE = 2048

    def initialize(name, input, input_name, output)
      super(name)
      @input = InputStreamReader.new(input)
      @input_name = input_name
      @output = output
      setPriority(java.lang.Thread::MAX_PRIORITY-1)
    end

    def run()
      begin
        cbuf = Array.new(BUFFER_SIZE).to_java(:char)
        while ((count = @input.read(cbuf, 0, BUFFER_SIZE)) >= 0 )
          dat = cbuf[0..count-1].map {|x| x.chr}.join().chomp
          @output.puts dat.split("\n").map {|l| "** #{@input_name} => #{l}"}
        end
        @output.flush()
      rescue IOException => exc
        STDERR.puts("Child I/O Transfer - #{exc}")
      end
    end
  end


  attr_reader   :java_version, :writer, :watchFields, :debugTraceMode, 
                :excludes, :includes, :meth_regex,
                :mainArgs, :vm

  DEFAULT_EXCLUDES = [
    # Base java/sun stuff to exclude
    "java.*", "javax.*", "sun.*", "com.sun.*", 
    # several exclusions for jruby/jirb targets
    "org.jruby.*", "jline.*", "ruby.*", "org.jcodings.*", "jruby.*", 
    "org.joni.*"
  ]

  def initialize(args)
    @watchFields = false
    @launching_connector = "com.sun.jdi.CommandLineLaunch"
    @java_version = java.lang.System.getProperty("java.version")
    if @java_version < "1.6"
      STDERR.puts "** WARN: Java < v1.6 - method argument dumps unavailable **"
    end
    parseargs(args)
    @debugTraceMode ||= 0
    @excludes ||= DEFAULT_EXCLUDES
    @writer ||= STDOUT
  end

  # Parse JdiTrace command-line arguments
  def parseargs(ary)
    args = ary.dup
    op = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options] class args"

      opts.separator ""
      opts.separator "Options:"

      opts.on_tail("-h", "--help", "Show this message") do
        STDERR.puts opts
        exit 1
      end

      opts.on("-o", "--output FILE", "Output trace to FILE") do |o|
        @writer = File.open(o, "wb")
      end

      opts.on("-f", "--fields", "watch fields") do
        @watchFields = true
      end

      opts.on("-d", "--dbgtrace NUM", Numeric, 
              "debug trace mode (Default: 0)") do |d|
        @debugTraceMode = d
      end

      opts.on("-e", "--exclude=LIST", "Exclude class patterns") do |e|
        @excludes = e.split(/\s*,\s*/).select {|x| not x.empty? }
      end

      opts.on("-i", "--include=LIST", "Include class patterns") do |i|
        @includes = i.split(/\s*,\s*/).select {|x| not x.empty? }
      end

      opts.on("-m", "--match-method=REGEX", "Regex for method names") do |m|
        @meth_regex = Regexp.new(m)
      end

      opts.on("-a", "--attach ADDR", "Attach to socket for target") do  |a|
        @launching_connector = "com.sun.jdi.SocketAttach"
        if m=/^(?:([\w.]+):)?(\d+)$/.match(a)
          @port = m[2]
          @hostname = m[1]
        else
          raise "invalid arguments to --attach"
        end
      end

    end

    begin
      op.parse!(args) 
      if @port.nil?
        raise "<class> missing" unless args[0]
        @mainArgs = args
      else
        raise "unexpected arguments with --attach option" if args[0]
        @mainArgs = []
      end
    rescue
      STDERR.puts $!
      exit 1
    end

  end

  # Launch the target and start the trace.
  def go
    @vm = launchTarget()
    generateTrace()
  end

  # Generate the trace.
  # Enable events, start thread to display events, 
  # start threads to forward remote error and output streams,
  # resume the remote VM, wait for the final event, and shutdown.
  def generateTrace(writer=@writer)
    @vm.setDebugTraceMode(@debugTraceMode)
    evt_thread = EventThread.new(self)
    evt_thread.setEventRequests(@watchFields)
    evt_thread.start()
    STDERR.puts("======= starting trace =======")
    begin
      if @launching_connector == "com.sun.jdi.CommandLineLaunch"
        redirectOutput() 
        # make sure output is forwarded before we exit
        @err_thread.join 
        @out_thread.join
      end
      @vm.resume()
      evt_thread.join
    rescue InterruptedException => exc
      STDERR.puts "Got InterruptedException: #{exc}" 
      # we don't interrupt
    ensure
      @writer.close() if @writer.is_a?(File)
    end
  end

  # copy the target's output and error to our output and error
  def redirectOutput()
    process = @vm.process()
    @err_thread = StreamRedirectThread.new("target stderr reader",
                                           process.getErrorStream(),
                                           "Process STDERR",
                                           STDERR)

    @out_thread = StreamRedirectThread.new("target stdout reader",
                                           process.getInputStream(),
                                           "Process STDOUT",
                                           STDOUT)

    @err_thread.start()
    @out_thread.start()
    @err_thread.join()
    @out_thread.join()
  end

  # Launch target VM.
  # Forward target's output and error.
  def launchTarget(m_args=@mainArgs)
    connectors = Bootstrap.virtualMachineManager().allConnectors().to_a
    conn = connectors.find do |c|
      c.name == @launching_connector
    end

    if @launching_connector == "com.sun.jdi.CommandLineLaunch"
      return doCliConnectorArgs(conn, m_args)
    elsif @launching_connector == "com.sun.jdi.SocketAttach"
      return doSockConnectorArgs(conn)
    end
  end

  # Set up and return the launching connectors arguments Map
  def doCliConnectorArgs(conn, m_args=@mainArgs)
    c_args = conn.defaultArguments()
    c_args.get("main").setValue(m_args.join(' '))
    c_args.get("options").setValue("-classic") if @watchFields
    return conn.launch(c_args)
  end

  def doSockConnectorArgs(conn, m_args=@mainArgs)
    c_args = conn.defaultArguments()
    c_args.get("port").setValue(@port.to_i)
    c_args.get("hostname").setValue(@hostname) if @hostname
    conn.attach( c_args )
  end

end


JdiTrace.new(ARGV).go if __FILE__ == $0

