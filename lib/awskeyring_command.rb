require 'thor'

require_relative 'awskeyring'

class AwskeyringCommand < Thor
  desc 'ls NAME', 'Prints a list of items in the keyring'
  method_option :all, type: :boolean, aliases: '-a', default: false, desc: 'Print all the items, even Role and MFA items'
  def ls
    Awskeyring.ls(options[:all])
  end
end
