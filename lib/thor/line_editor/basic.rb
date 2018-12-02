# rubocop:disable all
class Thor
  module LineEditor
    class Basic
      attr_reader :prompt, :options

      def self.available?
        true
      end

      def initialize(prompt, options)
        @prompt = prompt
        @options = options
      end

      def readline
        $stdout.print(prompt)
        get_input
      end

      private

      def get_input
        if echo?
          $stdin.gets
        else
          require 'io/console'
          password = ''
          loop do
            character = $stdin.getch
            break unless character

            if ["\n", "\r"].include? character
              puts ''
              break
            elsif ["\b", "\u007f"].include? character
              password.chop!
              print "\b\e[P"
            elsif character == "\u0003"
              exit 1
            else
              print '*'
              password << character
            end
          end
          password
        end
      end

      def echo?
        options.fetch(:echo, true)
      end
    end
  end
end
