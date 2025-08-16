# frozen_string_literal: true

require 'debug'

class Flim
    attr_accessor :terminal, :filepath, :file, :virtual_buffer, :virtual_cursor

    def initialize(args)
        @terminal = IO.console
        @filepath = validate_args(args)
        @virtual_buffer = Array.new(terminal.winsize[0]) { Array.new(terminal.winsize[1], ' ') }
        @virtual_cursor = [0, 0]
    end

    # Control Chars
    INTERRUPT_SIGNAL = 3.chr

    # Escape Sequences
    SWITCH_TO_ALTERNATE_BUFFER = '?1049h'
    SWITCH_TO_MAIN_BUFFER = '?1049l'

    # CSI Sequences
    CURSOR_UP = 'A'
    CURSOR_DOWN = 'B'
    CURSOR_FORWARD = 'C'
    CURSOR_BACK = 'D'

    LAST_BYTE_CSI_SEQUENCE_REGEX = /(?<=\e\[).+/
    LAST_BYTE_CSI_SEQUENCE_CURSOR_MOVEMENT = %w[CURSOR_UP, CURSOR_DOWN, CURSOR_FORWARD, CURSOR_BACK].freeze

    # Event Loop
    def run
        setup
        begin
            loop do
                terminal.raw do |io|
                    # 1. Event Loop starts
                    log("<LOOP_START> - virtual_cursor: #{virtual_cursor}, terminal.cursor: #{terminal.cursor}")

                    # 2. Wait for input (BLOCKING)
                    buffer = io.readpartial(256) # Read a larger chunk
                    log("<RECEIVED INPUT - buffer: #{buffer}")

                    # 3. Process input and update virtual buffer/cursor
                    process_input(buffer)

                    # 4. Sync cursors
                    terminal.cursor = [*virtual_cursor]
                end
            end
        rescue StandardError => e
            teardown(error: e)
        end
    end

    private

    # <<< EVENT LOOP >>

    def process_input(buffer)
        # Control Char or Printable Char
        if buffer.bytesize == 1
            # Control Char
            if buffer.ord.between?(0, 31) || buffer.ord >= 127
                # Specifically handle each control char
                case buffer.ord
                when 3
                    teardown
                end
            end

            # Printable char (letters, numbers, chars etc.)
            virtual_buffer_update_char(buffer) if buffer.ord.between?(32, 126)
            print(buffer)

        # CSI Sequence
        elsif buffer.start_with?("\e[")
            last_byte = buffer.match(LAST_BYTE_CSI_SEQUENCE_REGEX)[0]
            case last_byte
            when CURSOR_UP
                virtual_cursor[0] -= 1
            when CURSOR_DOWN
                virtual_cursor[0] += 1
            when CURSOR_FORWARD
                virtual_cursor[1] += 1
            when CURSOR_BACK
                virtual_cursor[1] -= 1
            end
        else
            $stdout.print 'not recognized'
        end
    end

    # <<< HELPER METHODS >>>

    def setup
        @file = if File.exist?(filepath)
                    File.open(filepath)
                else
                    File.new(filepath, 'w')
                end

        execute_escape_code(SWITCH_TO_ALTERNATE_BUFFER)
        rows, cols = terminal.winsize
        terminal.goto(0, 0)

        # Ingest existing file state and display in terminal
        return if file.size.zero?

        file.each_line.with_index do |line, r|
            line.each_char.with_index do |char, c|
                virtual_buffer[r][c] = char
            end
        end
        virtual_cursor = [0, 0]
        sync_console_to_virtual_buffer
    end

    def teardown(error: nil)
        execute_escape_code(SWITCH_TO_MAIN_BUFFER)
        file.close
        warn("Flim closed unexpectedly due to the following error: #{error.message}") if error
        exit
    end

    def validate_args(args)
        raise 'Please supply exactly one filename as an argument' if args.count != 1

        args[0]
    end

    def virtual_buffer_update_char(char)
        virtual_buffer[virtual_cursor[0]][virtual_cursor[1]] = char
        virtual_cursor[1] += 1
    end

    def execute_escape_code(code)
        $stdout.print "\e[#{code}"
    end

    def log(message)
        File.write('log.txt', message + "\n", mode: 'a')
    end
end
