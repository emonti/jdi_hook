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
      "#{self.full_name}(#{args.join(', ')})"
    end
    alias jh_describe jh_describe_method
  end

  module MethodEntryEvent
    def jh_describe_event(opts={})
      self.thread.frame(0).jh_describe_method_entry
    end
  end

  module MethodExitEvent
    def jh_describe_event(opts={})
      extra = 
        if( java.lang.System.getProperty("java.version") >= "1.6" and
            self.virtualMachine.can_get_method_return_values? )
           " returns (#{self.returnValue.type.name}: #{self.returnValue})"
        end

      "MethodExit: #{ self.method.full_name }#{ extra }"
    end
  end

  module StackFrame
    def jh_describe_method_entry
      meth = self.location.method

      # argument values are only available in java 1.6
      if java.lang.System.getProperty("java.version") >= "1.6"
        args = []
        arg_types = meth.argumentTypeNames.to_a
        arg_values = self.argumentValues.to_a
        begin
          arg_values.size.times do |i|
            args[i] = "#{arg_types[i]}: #{arg_values[i]}"
          end
        rescue InternalException => exc
          ["ERR: #{exc}"]
        rescue IncompatibleThreadStateException
          ["ERR: got IncompatibleThreadStateException"]
        end
        "Method Entry: #{meth.full_name}(#{args.join(', ')})"
      else
        meth.jh_describe_method
      end
    end
  end
end
