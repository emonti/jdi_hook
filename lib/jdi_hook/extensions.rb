# This file contains ruby method decorations to various JDI Java classes 
# imported into the JdiHook ruby namespace at the top-level in jdi_hook.rb

module JdiHook
  class ArrayReferenceImpl
    def to_s
      self.values.to_s
    end
  end

  module JdiMethod
    def full_name
      "#{self.declaringType.name}.#{self.name}"
    end

    def jh_describe_method(opts={})
      args = self.argumentTypeNames.to_a
      "#{self.full_name}(#{args.join(', ')})\n"
    end
    alias jh_describe jh_describe_method
  end

  module MethodEntryEvent
    # returns a printable description of a single method entry
    #   Meaningful hash options:
    #     :frame    = optional stack frame index (note: 0 is highest on stack)
    def jh_describe_event(opts={})
      f_idx = opts[:frame] || 0
      "MethodEntry: #{self.thread.frame(f_idx).jh_describe_method_entry}"
    end
    
    # returns a printable description string of the call-stack
    #   Meaningful hash options:
    #     :start    = optional start index in stack frames list
    #     :maxdepth = optional maximum depth number
    def jh_describe_callstack(opts={})
      fcount = self.thread.frame_count
      start = opts[:start] || 0
      depth = (d=opts[:maxdepth] && d > 0 && d < fcount)? d : fcount
      ret = "CallStack [displayed #{depth}/#{fcount}]:\n"
      self.thread.frames(start, depth).each_with_index do |f,i| 
        ret << "    [#{i}] #{f.jh_describe_method_entry}}\n"
      end
      return ret
    end
  end

  module MethodExitEvent
    def jh_describe_event(opts={})
      extra = 
        if JdiHook::JVM_VERSION >= "1.6" and self.virtualMachine.can_get_method_return_values?
           " returns (#{self.returnValue.type.name}: #{self.returnValue})"
        end

      "MethodExit: #{self.method.full_name}#{extra}"
    end
  end

  module StackFrame
    def jh_describe_method_entry
      meth = self.location.method

      # argument values are only available in java 1.6
      if JdiHook::JVM_VERSION >= "1.6"
        args = []
        begin
          arg_types = meth.argumentTypeNames.to_a
          arg_values = self.argumentValues.to_a
          arg_values.size.times do |i|
            args[i] = "#{arg_types[i]}: #{arg_values[i]}"
          end
        rescue IncompatibleThreadStateException
          args << "ERR: got IncompatibleThreadStateException"
        rescue
          args << "ERR: got #{$!}"
        end
        "#{meth.full_name}(#{args.join(', ')})"
      else
        meth.jh_describe_method
      end
    end
  end
end
