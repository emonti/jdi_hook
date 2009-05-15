module JdiHook
  class EventThread < java.lang.Thread
    include_class [
      "java.lang.InterruptedException", 
      "com.sun.jdi.VMDisconnectedException",
      "com.sun.jdi.event.VMStartEvent",
      "com.sun.jdi.event.VMDeathEvent",
      "com.sun.jdi.event.VMDisconnectEvent",
    ]

    attr_reader :connected

    def initialize( handler )
      @handler = handler
      @vm = handler.vm
    end

    def start(*args)
      @connected = true
      super(*args)
    end

    def run()
      queue = @vm.eventQueue()
      while @connected
        begin
          events = queue.remove
          events.each do |evt|
            @connected=false if evt.is_a? VMDisconnectEvent
            @handler.receive_event(evt) if @handler.respond_to?(:receive_event)
          end
          events.resume()
        rescue InterruptedException
          # ignore
        rescue VMDisconnectedException
          # A VMDisconnectedException has happened while dealing with
          # another event. We need to bail so that we terminate correctly. 
          # XXX do we really need to do this?
          @connected=false
          break
        end
      end
    end

    # A VMDisconnectedException has happened while dealing with
    # another event. We need to flush the event queue, dealing only
    # with exit events (VMDeath, VMDisconnect) so that we terminate
    # correctly.
    def handleDisconnectedException
      queue = @vm.eventQueue()
      while @connected
        begin
          eventSet = queue.remove()
          eventSet.each do |event|
            if VMDeathEvent === event
              vmDeathEvent(event)
            elsif VMDisconnectEvent === event
              vmDisconnectEvent(event)
            end
          end
        rescue InterruptedException
          # ignore
        end
      end
    end

  end
end
