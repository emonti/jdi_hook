include Java

include_class [
  "com.sun.jdi.InternalException",
  "com.sun.jdi.IncompatibleThreadStateException",
  "com.sun.jdi.event.MethodEntryEvent",
  "com.sun.jdi.event.MethodExitEvent",
]

module JdiHook
  module UtilHelpers
    def java_method_name(meth)
      meth.full_name
    end
  end

  module EventHelpers
    include UtilHelpers

    def describe_method_entry(meth, frame=nil)
      if frame and java.lang.System.getProperty("java.version") >= "1.6"
        args =
          begin
            frame.argument_values().to_a.map {|v| v || "null" }
          rescue InternalException => exc
            ["ERR: #{exc}"]
          rescue IncompatibleThreadStateException
            ["ERR: got IncompatibleThreadStateException"]
          end
        "#{meth.full_name}(#{args.join(', ')})"
      else
        meth.jh_describe
      end
    end

    def describe_method_exit(meth, frame=nil)
      # TODO... more?
      m_name = meth.full_name
    end

  end
end


