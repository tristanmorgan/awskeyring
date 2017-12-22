require 'keychain'
require 'aws-sdk-iam'

require 'awskeyring/version'

# Aws Key-ring logical object,
# gives you an interface to access keychains and items.
module Awskeyring
  PREFS_FILE = (File.expand_path '~/.awskeyring').freeze
  ROLE_PREFIX = 'role '.freeze
  ACCOUNT_PREFIX = 'account '.freeze

  def self.prefs
    if File.exist? PREFS_FILE
      JSON.parse(File.read(PREFS_FILE))
    else
      {}
    end
  end

  def self.init_keychain(awskeyring:)
    keychain = Keychain.create(awskeyring)
    keychain.lock_interval = 300
    keychain.lock_on_sleep = true

    prefs = { awskeyring: awskeyring }
    File.new(Awskeyring::PREFS_FILE, 'w').write JSON.dump(prefs)
  end

  def self.load_keychain
    unless File.exist?(Awskeyring::PREFS_FILE) || prefs.empty?
      warn "Config missing, run `#{$PROGRAM_NAME} initialise` to recreate."
      exit 1
    end

    keychain = Keychain.open(prefs['awskeyring'])
    if keychain && keychain.lock_interval > 300
      warn 'It is STRONGLY reccomended to set your keychain to lock in 5 minutes or less.'
    end
    keychain
  end

  def self.list_items
    items = all_items.all.sort do |a, b|
      a.attributes[:label] <=> b.attributes[:label]
    end
    items.select { |elem| elem.attributes[:label].start_with?(ACCOUNT_PREFIX) }
  end

  def self.list_roles
    items = all_items.all.sort do |a, b|
      a.attributes[:label] <=> b.attributes[:label]
    end
    items.select { |elem| elem.attributes[:label].start_with?(ROLE_PREFIX) }
  end

  def self.all_items
    load_keychain.generic_passwords
  end

  def self.add_item(account:, key:, secret:, comment:)
    all_items.create(
      label: "#{ACCOUNT_PREFIX}#{account}",
      account: key,
      password: secret,
      comment: comment
    )
  end

  def self.add_role(role:, arn:, account:)
    all_items.create(
      label: "#{ROLE_PREFIX}#{role}",
      account: arn,
      password: '',
      comment: account
    )
  end

  def self.get_item(account)
    all_items.where(label: "#{ACCOUNT_PREFIX}#{account}").first
  end

  def self.get_role(name)
    get_item("#{ROLE_PREFIX}#{name}")
  end

  def self.list_item_names
    list_items.map { |elem| elem.attributes[:label][(ACCOUNT_PREFIX.length)..-1] }
  end

  def self.list_role_names
    list_roles.map { |elem| elem.attributes[:label][(ROLE_PREFIX.length)..-1] }
  end

  def self.delete_expired(key, token)
    expires_at = Time.at(key.attributes[:comment].to_i)
    if expires_at < Time.now
      delete_pair(key, token, '# Removing expired session credentials')
      key = nil
      token = nil
    end
    [key, token]
  end

  def self.delete_pair(key, token, message)
    puts message if message
    token.delete if token
    key.delete if key
  end
end
