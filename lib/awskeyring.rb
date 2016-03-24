require 'keychain'
require 'aws-sdk'

require 'awskeyring/version'

module Awskeyring
  def self.ls(_all_flag)
    keychain = load_keychain
    items = keychain.generic_passwords.all.sort do |a, b|
      a.attributes[:label] <=> b.attributes[:label]
    end

    items.each do |item|
      puts "  #{item.attributes[:label]}"
    end
  end

  PREFS_FILE = File.expand_path '~/.aws-keychain-util'

  def self.load_default_keychain
    name = prefs['aws_keychain_name']
    name ? Keychain.open(name) : Keychain.default
  end

  def self.prefs
    if File.exist? PREFS_FILE
      JSON.parse(File.read(PREFS_FILE))
    else
      {}
    end
  end

  def self.load_keychain
    keychain = load_default_keychain
    if keychain && keychain.lock_interval > 300
      $stderr.puts 'Your keychain is *not* set to lock automatically in under five minutes. This could be dangerous.'
      unless File.exist? AwsKeychainUtil::PREFS_FILE
        $stderr.puts "You should probably run `#{$PROGRAM_NAME} init` to create a new, secure keychain."
      end
    end
    keychain
  end
end
