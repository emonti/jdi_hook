$: << "lib"
require 'jdi_hook'

vm = JdiHook.command_line_launch("HelloWorld")
dbg = JdiHook::MethodTracer.new vm, 
  :redirect_stdio => true

en_proc = lambda {|this, evt| puts " [*] " << this.notify_entry(evt.method) }
ex_proc = lambda {|this, evt| puts " [*] " << this.notify_exit(evt.method) }

dbg.meth_hooks = { 
  /\.main$/ => { :on_entry => en_proc, :on_exit => ex_proc },
  /.*/      => { :on_entry => en_proc },
}

dbg.go

