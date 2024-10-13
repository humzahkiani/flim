# frozen_string_literal: true

require 'io/console'
require 'debug'

# Main Entrypoint
class Flim
  attr_accessor :virtual_console, :console

  def initialize(args)
    validate_args(args)
    dimension = 30
    execute_escape_code('?1049h')
    self.console = IO.console # Might not fully replace $stdin
    self.virtual_console = Array.new(dimension) { Array.new(dimension, '') }
  end

  def run
    # 0. Setup
    #   Switch to alternate buffer - \e[?1049h
    #   Start from top, and top left (no scrollback showing)
    #   When exiting program, return to main buffer - \e[?1049l
    virtual_console[5] = virtual_console[5].map { '-' }
    virtual_console[25] = virtual_console[25].map { '-' }

    move_cursor(1, 1)
    # Event loop
    loop do
      # 1. Display current window + cursor + text
      line, col = cursor_position

      # sync console to virtual console (DRAW)
      sync_consoles(line, col)

      # 2. Check for input signals (keystrokes)
      response = String.new
      console.raw do |io|
        response << io.readpartial(10)
      end
      key = response.scan(/(?<=\e\[).+?/).first

      # 3. Process input signals
      if response == INTERRUPT
        execute_escape_code('?1049l')
        break
      end

      next unless MOVEMENT_KEYS.include?(key)

      line, col = cursor_position
      case key
      when 'A'
        move_cursor(line - 1, col)
      when 'B'
        move_cursor(line + 1, col)
      when 'C'
        move_cursor(line, col + 1)
      when 'D'
        move_cursor(line, col - 1)
      end
    end
  end

  private

  INTERRUPT = 3.chr
  ERASE_LINE = '0K'
  CURSOR_POSITION = '6n'
  MOVEMENT_KEYS = %w[A B C D].freeze

  def sync_consoles(line_original, col_original)
    line_start = 1
    col_start = 1
    virtual_console.each_with_index do |line, line_i|
      line.each_with_index do |cell, cell_i|
        move_cursor(line_start + line_i, col_start + cell_i)
        print cell
      end
    end
    move_cursor(line_original, col_original)
  end

  def terminal_window_size
    IO.console.winsize
  end

  def validate_args(args)
    return unless args.size > 1

    raise 'You may supply at most one filename as an argument'
  end

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
end
