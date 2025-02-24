# frozen_string_literal: true

require 'debug'

class Flim
    attr_accessor :terminal, :filepath, :file, :virtual_buffer, :virtual_cursor

    def initialize(args)
        @terminal = IO.console
        @filepath = validate_args(args)
        @virtual_buffer = []
        @virtual_cursor = [0,0]
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
                    sync_console_to_virtual_buffer

                    buffer = io.readpartial(256) # Read a larger chunk
                    next if buffer.empty?

                    process_input(buffer)
                end
            end
        rescue StandardError => e
            teardown(error: e)
        end
    end

    private

    def sync_console_to_virtual_buffer
        terminal.goto(0,0)
        virtual_buffer.each do |line|
            print line
        end 
        terminal.cursor = virtual_cursor
    end 

    def setup
        if File.exist?(filepath)
            @file = File.open(filepath)
        else
            @file = File.new(filepath, 'w')
        end

        execute_escape_code(SWITCH_TO_ALTERNATE_BUFFER)
        terminal.goto(0,0)

        # Ingest existing file state and display in terminal
        unless file.size.zero?
            file.each_line do |line|
                virtual_buffer << line
            end
        end
    end

    def teardown(error: nil)
        execute_escape_code(SWITCH_TO_MAIN_BUFFER)
        file.close
        if error
            $stderr.puts("Flim closed unexpectedly due to the following error: #{error.message}")
        end
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
            if buffer.ord.between?(32, 126)
                virtual_buffer_update_char(buffer)
            end

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
            print 'not recognized'
        end
    end

    def execute_escape_code(code)
        print "\e[#{code}"
    end
end
