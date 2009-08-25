$: << "lib"
require 'jdi_hook'

vm = JdiHook.socket_attach(8000)
dbg = JdiHook::MethodTracer.new vm, 
  :redirect_stdio => true

en_proc = lambda {|this, evt| puts " [*] #{evt.jh_describe_event}" }
#en_proc = lambda {|this, evt| puts " [*] #{evt.jh_describe_callstack(:depth => 10)}" }
ex_proc = lambda {|this, evt| puts " [*] #{evt.jh_describe_event}" }

dbg.meth_hooks = { 
  /\.*$/ => { :on_entry => en_proc, :on_exit => ex_proc },
}

dbg.go

