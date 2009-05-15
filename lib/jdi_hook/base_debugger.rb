module JdiHook
  # This is a base wrapper class for setting up an event handler for event
  # requests in a debugee target VM.
  #
  # Implementations should override the following callbacks: 
  # create_event_requests, receive_event, and cleanup
  class BaseDebugger
    include_class [  
      "java.lang.InterruptedException",
      "com.sun.jdi.request.EventRequest",
    ] 

    attr_accessor :class_filters_exc, :class_filters_inc
    attr_reader   :vm

    DEFAULT_EXCLUDES = [
      # Base java/sun stuff to exclude
      "java.*", "javax.*", "sun.*", "com.sun.*", 
      # several exclusions for jruby/jirb targets
      "org.jruby.*", "jline.*", "ruby.*", "org.jcodings.*", "jruby.*", 
      "org.joni.*"
    ]

    def initialize(vm, opts={})
      @vm = vm
      @class_filters_exc = opts[:class_filters_exc] || DEFAULT_EXCLUDES
      @class_filters_inc = opts[:class_filters_inc] || Array.new
      @debug_mode = opts[:debug_mode] || 0
      @redirect_stdio = opts[:redirect_stdio]
    end

    # This method begins the debugging session setting up the event
    # handler and 
    def go
      @vm.setDebugTraceMode(@debug_mode)
      create_event_requests(@vm.eventRequestManager() )
      @evt_thread = EventThread.new(self)
      @evt_thread.start()
      if @redirect_stdio
        redirect_target_output($stdout, $stderr) 
      end

      begin
        @vm.resume()
        @evt_thread.join()
      rescue InterruptedException => e
        STDERR.puts "** Got InterruptedException: #{exc}"
      ensure
        cleanup()
        @evt_thread = nil
      end
    end

    # This method adds class exclusion and inclusion filters to an
    # event request. It should be called from overridden create_event_requests
    # implementations while setting up new event requests for the target VM.
    def filter_classes(req)
      if exc=@class_filters_exc
        exc.each {|e| req.addClassExclusionFilter(e) }
      end
      if inc=@class_filters_inc
        inc.each {|i| req.addClassFilter(i) }
      end
    end

    # This is a callback to set up event requests.
    # It is called with one argument 'mgr' which is the event request
    # manager for the target VM.
    def create_event_requests(mgr)
      # stub
    end

    # This is a callback to dispatch incoming events
    # override it to perform whatever specific actions you want based
    # on the event type
    def receive_event(event)
      # stub
    end

    # This is a callback to handle the end of the debugging session
    # override it to perform any cleanup tasks or wrap up.
    def cleanup()
      # stub
    end

    # This method starts and joins threads to redirect stderr and stdout from 
    # the target process. Capturing IO this way from the target is generally
    # only possible if the target is connected through a command line 
    # launch connector.
    #
    # This method should only be called from the 'go' method after the
    # primary event thread has been started but before it has been 
    # joined.
    def redirect_target_output(out=$stdout, err=$stderr)
      if process = @vm.process()
        unless @evt_thread and @evt_thread.connected
          raise "the event thread has not yet been started"
        end
        out_thread = StreamRedirectThread.new("target stdout reader",
                                               process.getInputStream(),
                                               "Process STDOUT",
                                               out)

        err_thread = StreamRedirectThread.new("target stderr reader",
                                               process.getErrorStream(),
                                               "Process STDERR",
                                               err)

        out_thread.start()
        err_thread.start()
        out_thread.join()
        err_thread.join()
        return [out_thread, err_thread]
      else
        STDERR.puts "WARNING: can't redirect output on this target'"
      end
    end
  end
end
