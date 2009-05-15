
module JdiHook
  class StreamRedirectThread < java.lang.Thread
    include_class "java.io.IOException"

    BUFFER_SIZE = 2048
    PRIORITY = java.lang.Thread::MAX_PRIORITY-1

    # Parameters:
    #   name   = a name for this thread for display purposes
    #   input  = java input stream
    #   label  = label for output
    #   output = ruby output object
    #   bufsz  = read buffer size (Default: BUFFER_SIZE)
    #   pri    = thread priority (Default: PRIORITY)
    def initialize(name, input, label, output, bufsz=nil, pri=nil)
      super(name)
      @input = java.io.InputStreamReader.new(input)
      @label = label
      @output = output
      @bufsz = bufsz || BUFFER_SIZE
      setPriority(pri || PRIORITY)
    end

    def run()
      begin
        cbuf = Array.new(@bufsz).to_java(:char)
        while ((count = @input.read(cbuf, 0, @bufsz)) >= 0 )
          dat = cbuf[0,count].map {|x| x.chr}.join().chomp
          @output.puts dat.split("\n").map {|l| "** #{@label} => #{l}"}
        end
        @output.flush()
      rescue IOException => exc
        STDERR.puts("Child I/O Transfer - #{exc}")
      end
    end
  end
end

