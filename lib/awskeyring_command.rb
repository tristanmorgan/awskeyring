require 'thor'

require_relative 'awskeyring'

# AWS Key-ring command line interface.
class AwskeyringCommand < Thor
  desc 'ls NAME', 'Prints a list of items in the keyring'
  method_option :all, type: :boolean, aliases: '-a', default: false,
                      desc: 'Print all the items, even Role and MFA items'
  def ls
    items = Awskeyring.get_items(options[:all])
    items.each do |item|
      puts "  #{item.attributes[:label]}"
    end
  end
end
