# frozen_string_literal: true

require 'io/console'
require 'debug'

# Main Entrypoint
class Flim
  attr_accessor :virtual_console, :console, :file

  def initialize(args)
    validate_args(args)
    filename = args.first

    @file = create_or_find_file(filename)
    @console = IO.console # Might not fully replace $stdin
    @virtual_console = Array.new(DIMENSION) { String.new }
  end

  def run
    # Setup
    switch_to_alternate_buffer
    move_cursor(1, 1)

    sync_virtual_console_to_file
    # Core event loop
    loop do
      line, col = cursor_position
      sync_consoles(line, col)

      response, key = detect_input_signal

      process_input_signal = process_input_signal_proc
      process_input_signal.call(response, key)
    end
  end

  private

  DIMENSION = 30

  INTERRUPT = 3.chr
  ERASE_LINE = '0K'
  CURSOR_POSITION = '6n'
  SWITCH_TO_ALTERNATE_BUFFER = '?1049h'
  SWITCH_TO_MAIN_BUFFER = '?1049l'
  MOVEMENT_KEYS = %w[A B C D].freeze

  def update_virtual_console_char(line, col, key)
    virtual_console.append("\n") while line > virtual_console.size
    virtual_console[line - 1] = String.new if virtual_console[line - 1] == "\n"
    virtual_console[line - 1] << String.new(' ') while col > virtual_console[line - 1].length
    virtual_console[line - 1] << "\n"

    virtual_console[line - 1][col - 1] = key
  end

  def sync_file_to_virtual_console
    file.rewind
    virtual_console.each do |line|
      file.write(line)
    end
  end

  def sync_virtual_console_to_file
    self.virtual_console = file.readlines
  end

  def create_or_find_file(filename)
    if File.exist?(filename)
      File.open(filename, 'r+')
    else
      File.new(filename, 'a+')
    end
  end

  def process_input_signal_proc
    proc do |response, key|
      if response == INTERRUPT
        sync_file_to_virtual_console

        file.close
        switch_to_main_buffer
        raise StopIteration
      end

      line, col = cursor_position
      if response.to_s.length == key.length
        update_virtual_console_char(line, col, key)
        print(key)
        next
      end
      next unless MOVEMENT_KEYS.include?(key)

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

  def detect_input_signal
    response = String.new
    console.raw do |io|
      response << io.readpartial(10)
    end
    key = response.scan(/(?<=\e\[).+?/).first
    key = response if response.to_s.length == 1
    [response, key]
  end

  def switch_to_alternate_buffer
    execute_escape_code(SWITCH_TO_ALTERNATE_BUFFER)
  end

  def switch_to_main_buffer
    execute_escape_code(SWITCH_TO_MAIN_BUFFER)
  end

  def sync_consoles(line_original, col_original)
    line_start = 1
    col_start = 1
    virtual_console.each_with_index do |line, line_i|
      line_length = line.length
      line_length.times do |col_i|
        move_cursor(line_start + line_i, col_start + col_i)
        char = line[col_i]
        print char
      end
    end
    move_cursor(line_original, col_original)
  end

  def validate_args(args)
    raise 'You may supply only one filename as an argument' if args.size != 1
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
    console.raw do |io|
      execute_escape_code(CURSOR_POSITION)

      response << io.readpartial(1) until response[-1] == 'R'
    end

    response.scan(/\d+/).map(&:to_i)
  end
end
