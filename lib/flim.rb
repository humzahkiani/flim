# frozen_string_literal: true

require 'debug'

class Flim
    attr_accessor :terminal, :filepath, :file, :virtual_buffer

    def initialize(args)
        @terminal = IO.console
        @filepath = validate_args(args)
        @virtual_buffer = []
    end

    SWITCH_TO_ALTERNATE_BUFFER = '?1049h'
    SWITCH_TO_MAIN_BUFFER = '?1049l'
    INTERRUPT_SIGNAL = 3.chr

    LAST_BYTE_CSI_SEQUENCE_REGEX = /(?<=\e\[).+/
    LAST_BYTE_CSI_SEQUENCE_CURSOR_MOVEMENT = %w[A B C D].freeze

    # Event Loop
    def run
        setup

        loop do
            terminal.raw do |io|
                buffer = io.readpartial(256) # Read a larger chunk
                next if buffer.empty?

                process_input(buffer)
            end
        end
    end

    private

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

            virtual_buffer.each do |line|
                print line
            end
        end
    end

    def teardown
        execute_escape_code(SWITCH_TO_MAIN_BUFFER)
        file.close
        exit
    end

    def validate_args(args)
        raise 'Please supply exactly one filename as an argument' if args.count != 1

        args[0]
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
            print buffer if buffer.ord.between?(32, 126)

        # CSI Sequence
        elsif buffer.start_with?("\e[")
            last_byte = buffer.match(LAST_BYTE_CSI_SEQUENCE_REGEX)[0]
            case last_byte
            when *LAST_BYTE_CSI_SEQUENCE_CURSOR_MOVEMENT
                print buffer
            end
        else
            print 'not recognized'
        end
    end

    def execute_escape_code(code)
        print "\e[#{code}"
    end
end
