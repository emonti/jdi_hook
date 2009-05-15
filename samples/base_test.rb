$: << "lib"
require 'jdi_hook'

vm = JdiHook.command_line_launch("HelloWorld")
dbg = JdiHook::BaseDebugger.new(vm, :redirect_stdio => true)
dbg.go

