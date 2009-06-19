$: << "lib"
require 'jdi_hook'

vm = JdiHook.command_line_launch("HelloWorld")
dbg = JdiHook::MethodTracer.new vm, 
  :redirect_stdio => true

en_proc = lambda {|this, evt| puts " [*] " << evt.jh_describe }
ex_proc = lambda {|this, evt| puts " [*] " << evt.jh_describe }

dbg.meth_hooks = { 
  /\.main$/ => { :on_entry => en_proc, :on_exit => ex_proc },
  /.*/      => { :on_entry => en_proc },
}

dbg.go

