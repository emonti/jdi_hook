# This file contains ruby method extensions to several JDI java classes which
# have been imported into the JdiHook ruby namespace from the top-level 
# jdi_hook.rb

module JdiHook
  module JdiMethod
    def full_name
      "#{self.declaringType.name}.#{self.name}"
    end

    def jh_describe(opts={})
      args = self.argumentTypeNames.to_a
      "#{self.full_name}(#{args.join(', ')})"
    end
  end

  module MethodEntryEvent
    include EventHelpers

    def jh_describe(opts={})
      frame_idx = opts[:frame_idx] || 0
      "MethodEntry: " +
        describe_method_entry(self.method, self.thread.frame(frame_idx))
    end
  end

  module MethodExitEvent
    include EventHelpers
    def jh_describe(opts={})
      frame_idx = opts[:frame_idx] || 0
      "MethodExit: " +
        describe_method_exit(self.method, self.thread.frame(frame_idx))
    end
  end
end
