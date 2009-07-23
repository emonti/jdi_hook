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
end


