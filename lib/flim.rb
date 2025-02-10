# frozen_string_literal: true

require 'debug'

class Flim
  attr_writer :terminal

  def initialize
    @terminal = IO.console
  end

  SWITCH_TO_ALTERNATE_BUFFER = '?1049h'
  SWITCH_TO_MAIN_BUFFER = '?1049l'
  
  # Event Loop
  def run
    
    # 1. Switch to alternative buffer
    execute_escape_code(SWITCH_TO_ALTERNATE_BUFFER)
    loop do
      input_sequence = String.new
      $stdin.raw do |io|
        buffer = io.readpartial(256) # Read a larger chunk
        next if buffer.empty? # Exit on end of input (if spported)
        
        # Control C Escape Sequence
        if buffer == "\x03"
            exit
        end 
      end
    end 
  end

  def execute_escape_code(code)
    print "\e[#{code}"
  end
end

