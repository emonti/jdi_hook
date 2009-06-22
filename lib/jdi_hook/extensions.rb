# This file contains ruby method decorations to various JDI Java classes 
# imported into the JdiHook ruby namespace at the top-level in jdi_hook.rb

module JdiHook
  module JdiMethod
    def full_name
      "#{self.declaringType.name}.#{self.name}"
    end

    def jh_describe_method(opts={})
      args = self.argumentTypeNames.to_a
      "#{self.full_name}(#{args.join(', ')})"
    end
    alias jh_describe jh_describe_method

    def jh_describe_call(opts={})
      frame = opts[:frame]
      if frame and java.lang.System.getProperty("java.version") >= "1.6"
        args = 
          begin
            frame.argument_values().to_a.map {|v| v || "null" }
          rescue InternalException => exc
            ["ERR: #{exc}"]
          rescue IncompatibleThreadStateException
            ["ERR: got IncompatibleThreadStateException"]
          end
        "#{self.full_name}(#{args.join(', ')})"
      else
        self.jh_describe_method
      end
    end
  end

  class ArrayReferenceImpl
    def to_s
      self.values.to_s
    end
  end

  module MethodEntryEvent
    include EventHelpers

    def jh_describe_event(opts={})
      frame = self.thread.frame(0)
      "MethodEntry: #{ self.method.jh_describe_call(:frame => frame) }"
    end
  end

  module MethodExitEvent
    include EventHelpers
    def jh_describe_event(opts={})
      "MethodExit: #{self.method.full_name}"
    end
  end
end
