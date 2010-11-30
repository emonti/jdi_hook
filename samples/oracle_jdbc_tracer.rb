#!/usr/bin/env jruby
require 'rubygems'
require 'jdi_hook'

vm = JdiHook.socket_attach(8000)
dbg = JdiHook::MethodTracer.new(vm)

indent = 0

en_proc = lambda {|this, evt| puts "#{" "*indent} [*] #{evt.jh_describe_event}"; indent += 2 }
ex_proc = lambda {|this, evt| indent -= 2; puts "#{" "*indent} [*] #{evt.jh_describe_event}" }

dbg.meth_hooks = { 
  /oracle/ => { :on_entry => en_proc, :on_exit => ex_proc },
}

STDERR.puts "Starting hit-trace"
dbg.go
