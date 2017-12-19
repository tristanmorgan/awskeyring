require 'keychain'
require 'aws-sdk-iam'

require 'awskeyring/version'

# Aws Key-ring logical object,
# gives you an interface to access keychains and items.
module Awskeyring
  PREFS_FILE = File.expand_path '~/.aws-keychain-util'

  def self.get_items(_all_flag)
    keychain = load_keychain
    items = keychain.generic_passwords.all.sort do |a, b|
      a.attributes[:label] <=> b.attributes[:label]
    end
    items
  end

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
      warn 'Your keychain is *not* set to lock automatically in under five minutes. This could be dangerous.'
      unless File.exist? AwsKeychainUtil::PREFS_FILE
        warn "You should probably run `#{$PROGRAM_NAME} init` to create a new, secure keychain."
      end
    end
    keychain
  end

  def self.get_item(name)
    load_keychain.generic_passwords.where(label: name).first
  end

  def self.delete_expired(key, token)
    expires_at = Time.at(key.attributes[:comment].to_i)
    if expires_at < Time.now
      delete_pair(key, token, '# Removing expired STS credentials')
      key = nil
      token = nil
    end
    [key, token]
  end

  def self.delete_pair(key, token, message)
    puts message
    token.delete if token
    key.delete if key
  end
end
