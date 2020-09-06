# frozen_string_literal: true

# Awskeyring Module,
module Awskeyring
  # Input methods for Awskeyring
  module Input
    # Read a secret in without echoing the characters
    #
    # @param [String] prompt text to prompt user with.
    def self.read_secret(prompt)
      $stdout.print(prompt)
      hide_input
    end

    private_class_method def self.hide_input # rubocop:disable Metrics/MethodLength
      require 'io/console'
      password = +''
      loop do
        character = $stdin.getch
        break unless character

        case character
        when "\n", "\r"
          puts ''
          break
        when "\b", "\u007f"
          password.chop!
          print "\b\e[P"
        when "\u0003"
          exit 1
        else
          print '*'
          password << character
        end
      end
      password
    end
  end
end
