
module JdiHook
  class MethodTracer < BaseDebugger

    def initialize(vm, opts={})
      super(vm, opts)
      @meth_hooks = Array.new
      if hks = opts[:meth_hooks]
        self.meth_hooks=hks
      end
    end

    attr_reader :meth_hooks

    def meth_hooks=(enu)
      @meth_hooks = Array.new
      raise ":method_hooks must be Enumerable" unless enu.kind_of? Enumerable
      enu.each {|k,v| append_method_hook(k,v) }
    end

    def append_method_hook(m, val)
      unless m.is_a? String or m.is_a? Regexp
        raise "hook method key must be a String or Regex - got #{m.class}" 
      end
      unless val.is_a? Hash
        raise "hook value must me a kind of Hash - got #{block.class}" 
      end
      @meth_hooks << [m, val]
    end

    def find_method_hook(meth)
      @meth_hooks.each do |h|
        k, val = h
        if (k.is_a?(String) and meth == k) or (k.is_a?(Regexp) and meth =~ k)
          return h
        end
      end
      return nil
    end

    def create_event_requests(mgr)
      reqs = [ mgr.createMethodEntryRequest(), mgr.createMethodExitRequest() ]
      reqs.each do |req|
        filter_classes(req)
        req.setSuspendPolicy(EventRequest::SUSPEND_ALL)
        req.enable()
      end
    end

    def receive_event(event)
      case event
      when MethodEntryEvent  : handle_method_entry(event)
      when MethodExitEvent   : handle_method_exit(event)
      else
        STDERR.puts " [DEBUG] Received Event: #{event.java_class}" if $DEBUG
      end
    end

    def meth_name(meth)
      "#{meth.declaringType.name}.#{meth.name}"
    end

    def notify_entry(meth)
      m_name = meth_name(meth)
      args = meth.argumentTypeNames.join(', ')
      "MethodEntry: #{m_name}(#{args})"
    end

    def notify_exit(meth)
      m_name = meth_name(meth)
      "MethodExit: #{m_name}"
    end

    def handle_method_entry(event)
      meth = event.method
      m_name = meth_name(meth)
      if h=find_method_hook(m_name) 
        if block=h[1][:on_entry]
          block.call(self, event)
        end
      end
    end

    def handle_method_exit(event)
      meth = event.method
      m_name = meth_name(meth)
      if h=find_method_hook(m_name)
        if block=h[1][:on_exit]
          block.call(self, event)
        end
      end
    end

  end
end
