# frozen_string_literal: true

require 'io/console'
require 'debug'

def execute_escape_code(code)
  print "\e[#{code}"
end

def move_cursor(line, col)
  move_cursor_code = "\e[#{line};#{col}H"
  execute_escape_code(move_cursor_code)
end

def erase_line
  erase_line_code = '0K'
  execute_escape_code(erase_line_code)
end

# This is the cursor position relative to the viewport. It is NOT absolute. Will change on terminal scroll
def cursor_position
  # Need to handle output of control sequence without echoing to terminal
  response = String.new

  # Raw mode to handle cursor position as input stream without echoing
  $stdin.raw do |io|
    cursor_position_code = '6n'
    execute_escape_code(cursor_position_code)

    response << io.readpartial(1) until response[-1] == 'R'
  end

  response.scan(/\d+/).map(&:to_i)
end

off_text = 'FLIPPED OFF'
on_text = 'FLIPPED ON'
curr_text = off_text

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
  key = response.scan(/(?<=\e\[)C/).first
  next unless key == 'C'

  # 3. Process input signals
  curr_text = if curr_text == off_text
                on_text
              else
                off_text
              end
  # 4. Repeat
end
