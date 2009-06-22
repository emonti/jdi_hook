include Java

module JdiHook
  VERSION = '1.1.0'
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR

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
    "java.io.InputStreamReader",
    "java.lang.InterruptedException", 
    "java.util.List",
    "java.util.Map",
  ]

  include_class "com.sun.jdi.Method" do |pkg,name|
    "JdiMethod"
  end

  ## Class sugar methods

  # Shorthand for com.sun.jdi.Bootstrap.virtualMachineManager()
  def self.vm_mgr
    com.sun.jdi.Bootstrap.virtualMachineManager()
  end

  # Shorthand for com.sun.jdi.Bootstrap.virtualMachineManager.allConnectors()
  def self.vm_connectors
    vm_mgr.allConnectors()
  end

  # Launches a target VM by running it with commandline arguments and 
  # attaches to it.
  #
  # Returns: instance of VirtualMachineImpl
  #
  # Arguments:
  #   main = String or Array command line for class target
  #   o = an optional Hash of parameters:
  #     :options      = Additional options such as '-classic' (optional)
  #     :home         = JAVA_HOME path (default: probably your JAVA_HOME)
  #     :suspend      = whether to suspend the target on start (default: true)
  #     :vmexec       = what to run through exec (default: java)
  #     :quote        = the quote char for tokenizing args? (default: ")
  def self.command_line_launch(main, o=nil)
    o ||= {}
    o[:main] = [*main].join(' ')
    o[:options] = [*o[:options]].join(' ') if o[:options]
    con, args = get_connector("com.sun.jdi.CommandLineLaunch", o)
    return con.launch(args)
  end

  # Attaches to a running VM by process ID on the system.
  #
  # Note: Process attaching by pid only works if both the debugger and target 
  # VM are Java 1.6 or higher.
  #
  # Returns: instance of VirtualMachineImpl
  #
  # Arguments:
  #   pid = process ID to attach to
  #   o = an optional Hash of parameters:
  #     :timeout  = connection timeout? (optional)
  def self.process_attach(pid, o=nil)
    o ||= {}
    o[:pid] = pid.to_s
    con, args = get_connector("com.sun.jdi.ProcessAttach", o)
    return con.attach(args)
  end

  # Attaches to a running VM by opening a TCP socket to the target
  #
  # Returns: instance of VirtualMachineImpl
  #
  # Arguments:
  #   port = port to connect to
  #   o = an optional Hash of parameters:
  #     :hostname = host to connect to (default = localhost)
  #     :timeout  = connection timeout? (optional)
  def self.socket_attach(port, o=nil)
    o ||= {}
    o[:port] = port.to_i
    con, args = get_connector("com.sun.jdi.SocketAttach", o)
    return con.attach(args)
  end

  # Connects to a running VM by awaiting a connection via TCP socket
  # the target initiates the connection to this listener.
  #
  # Returns: instance of VirtualMachineImpl
  #
  # Arguments:
  #   port = port to listen on
  #   o = an optional Hash of parameters:
  #     :localAddress = address to listen on (default = 0.0.0.0)
  #     :timeout      = connection timeout? (optional)
  def self.socket_listen(port, o=nil)
    o ||= {}
    o[:port] = port.to_i
    con, args = get_connector("com.sun.jdi.SocketListen", o)
    return con.accept(args)
  end

  # Finds a connector of the given name from the virtual machine manager
  # and prepares arguments based on its defaultArguments()
  #
  # Returns: an array containing the connector and prepared arguments
  def self.get_connector(name, opts)
    unless con=vm_connectors.find {|c| c.name == name}
      raise "Can't get connector named #{name.inspect}'"
    end
    args = con.defaultArguments()
    opts.each {|k,v| args.get(k.to_s).setValue(v) }
    return [con, args]
  end

  ##### Cruft added by mr bones:

  # Returns the version string for the library.
  #
  def self.version
    VERSION
  end

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args )
    args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args )
    args.empty? ? PATH : ::File.join(PATH, args.flatten)
  end

  # Utility method used to require all files ending in .rb that lie in the
  # directory below this file that has the same name as the filename passed
  # in. Optionally, a specific _directory_ name can be passed in such that
  # the _filename_ does not have to be equivalent to the directory.
  #
  def self.require_all_libs_relative_to( fname, dir = nil )
    dir ||= ::File.basename(fname, '.*')
    search_me = ::File.expand_path(
        ::File.join(::File.dirname(fname), dir, '**', '*.rb'))

    Dir.glob(search_me).sort.each {|rb| require rb}
  end
end

require "jdi_hook/helpers.rb"
require "jdi_hook/extensions.rb"
require "jdi_hook/base_debugger.rb"
require "jdi_hook/event_thread.rb"
require "jdi_hook/method_tracer.rb"
require "jdi_hook/stream_redirect_thread.rb"

