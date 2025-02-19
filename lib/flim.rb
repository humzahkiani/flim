# frozen_string_literal: true

require 'debug'

class Flim
  attr_accessor :terminal

  def initialize
    @terminal = IO.console
  end

  SWITCH_TO_ALTERNATE_BUFFER = '?1049h'
  SWITCH_TO_MAIN_BUFFER = '?1049l'
  INTERRUPT_SIGNAL = 3.chr

  LAST_BYTE_CSI_SEQUENCE_REGEX = /(?<=\e\[).+/
  LAST_BYTE_CSI_SEQUENCE_CURSOR_MOVEMENT = ["A","B","C","D"].freeze

  # Event Loop
  def run
    
    # Switch to alternative buffer and set cursor
    execute_escape_code(SWITCH_TO_ALTERNATE_BUFFER)
    terminal.goto(0,0)

    loop do
      input_sequence = String.new
      terminal.raw do |io|
        buffer = io.readpartial(256) # Read a larger chunk
        next if buffer.empty? # Exit on end of input (if supported)

        process_input(buffer)
      end
    end
  end

  private

  def process_input(buffer)

    # Control Char or Printable Char
    if buffer.bytesize == 1
        # Control Char
        if buffer.ord.between?(0,31) || buffer.ord >= 127
          # Specifically handle each control char
          case buffer.ord
          when 3
            execute_escape_code(SWITCH_TO_MAIN_BUFFER)
            exit
          end
        end

        # Printable char (letters, numbers, chars etc.)
        if buffer.ord.between?(32,126)
          print buffer
        end
    #CSI Sequence 
    elsif buffer.start_with?("\e[")
      last_byte = buffer.match(LAST_BYTE_CSI_SEQUENCE_REGEX)[0]
      case last_byte
      when *LAST_BYTE_CSI_SEQUENCE_CURSOR_MOVEMENT
        print buffer
      end
    else
      print "not recognized"
    end
  end

  def execute_escape_code(code)
    print "\e[#{code}"
  end
end

