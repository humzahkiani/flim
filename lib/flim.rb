# frozen_string_literal: true

require 'io/console'
require 'debug'

INTERRUPT = 3.chr
ERASE_LINE = '0K'
CURSOR_POSITION = '6n'

def execute_escape_code(code)
  print "\e[#{code}"
end

def move_cursor(line, col)
  move_cursor_code = "\e[#{line};#{col}H"
  execute_escape_code(move_cursor_code)
end

def erase_line
  execute_escape_code(ERASE_LINE)
end

# This is the cursor position relative to the viewport. It is NOT absolute. Will change on terminal scroll
def cursor_position
  # Need to handle output of control sequence without echoing to terminal
  response = String.new

  # Raw mode to handle cursor position as input stream without echoing
  $stdin.raw do |io|
    execute_escape_code(CURSOR_POSITION)

    response << io.readpartial(1) until response[-1] == 'R'
  end

  response.scan(/\d+/).map(&:to_i)
end

off_text = 'FLIPPED OFF'
on_text = 'FLIPPED ON'
curr_text = off_text

ctrl_c = 3.chr

# Event loop
loop do
  # 1. Display current window + cursor + text
  line, col = cursor_position
  move_cursor(line, 1)
  erase_line
  print curr_text

  # 2. Check for input signals (keystrokes)
  response = String.new
  $stdin.raw do |io|
    response << io.readpartial(10)
  end
  key = response.scan(/(?<=\e\[).+?/).first

  # Control C interrupt event loop
  break if response == ctrl_c

  next unless key == 'C'

  # 3. Process input signals
  line, col = cursor_position
  move_cursor(line, col - 1)
  # 4. Repeat
end
