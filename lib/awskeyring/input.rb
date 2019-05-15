# frozen_string_literal: true

require 'io/console'

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
end
