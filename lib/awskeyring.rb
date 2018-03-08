require 'json'
require 'keychain'

# Awskeyring Module,
# gives you an interface to access keychains and items.
module Awskeyring # rubocop:disable Metrics/ModuleLength
  # Default rpeferences fole path
  PREFS_FILE = (File.expand_path '~/.awskeyring').freeze
  # Prefix for Roles
  ROLE_PREFIX = 'role '.freeze
  # Prefix for Accounts
  ACCOUNT_PREFIX = 'account '.freeze
  # Prefix for Session Keys
  SESSION_KEY_PREFIX = 'session-key '.freeze
  # Prefix for Session Tokens
  SESSION_TOKEN_PREFIX = 'session-token '.freeze

  # Retrieve the preferences
  #
  # @return [Hash] prefs of the gem
  def self.prefs
    if File.exist? PREFS_FILE
      JSON.parse(File.read(PREFS_FILE))
    else
      {}
    end
  end

  # Create a new Keychain
  def self.init_keychain(awskeyring:)
    keychain = Keychain.create(awskeyring)
    keychain.lock_interval = 300
    keychain.lock_on_sleep = true

    prefs = { awskeyring: awskeyring }
    File.new(Awskeyring::PREFS_FILE, 'w').write JSON.dump(prefs)
  end

  # Load the keychain for access
  #
  # @return [Keychain] keychain ready for use.
  def self.load_keychain
    unless File.exist?(Awskeyring::PREFS_FILE) && !prefs.empty?
      warn "Config missing, run `#{File.basename($PROGRAM_NAME)} initialise` to recreate."
      exit 1
    end

    keychain = Keychain.open(prefs['awskeyring'])
    if keychain && keychain.lock_interval > 300
      warn 'It is STRONGLY reccomended to set your keychain to lock in 5 minutes or less.'
    end
    keychain
  end

  # Return a list of all acount items
  def self.list_items
    items = all_items.all.sort do |a, b|
      a.attributes[:label] <=> b.attributes[:label]
    end
    items.select { |elem| elem.attributes[:label].start_with?(ACCOUNT_PREFIX) }
  end

  # Return a list of all role items
  def self.list_roles
    items = all_items.all.sort do |a, b|
      a.attributes[:label] <=> b.attributes[:label]
    end
    items.select { |elem| elem.attributes[:label].start_with?(ROLE_PREFIX) }
  end

  # Return all keychain items
  def self.all_items
    load_keychain.generic_passwords
  end

  # Add an account item
  def self.add_item(account:, key:, secret:, comment:)
    all_items.create(
      label: ACCOUNT_PREFIX + account,
      account: key,
      password: secret,
      comment: comment
    )
  end

  # update and account item
  def self.update_item(account:, key:, secret:)
    item = get_item(account: account)
    item.attributes[:account] = key
    item.password = secret
    item.save!
  end

  # Add a Role item
  def self.add_role(role:, arn:, account:)
    all_items.create(
      label: ROLE_PREFIX + role,
      account: arn,
      password: '',
      comment: account
    )
  end

  # add a session token pair of items
  def self.add_pair(params = {})
    all_items.create(label: SESSION_KEY_PREFIX + params[:account],
                     account: params[:key],
                     password: params[:secret],
                     comment: ROLE_PREFIX + params[:role])
    all_items.create(label: SESSION_TOKEN_PREFIX + params[:account],
                     account: params[:expiry],
                     password: params[:token],
                     comment: ROLE_PREFIX + params[:role])
  end

  # Return an account item by name
  def self.get_item(account:)
    all_items.where(label: ACCOUNT_PREFIX + account).first
  end

  # Return a role item by name
  def self.get_role(role_name:)
    all_items.where(label: ROLE_PREFIX + role_name).first
  end

  # Return a session token pair of items by name
  def self.get_pair(account:)
    session_key = all_items.where(label: SESSION_KEY_PREFIX + account).first
    session_token = all_items.where(label: SESSION_TOKEN_PREFIX + account).first if session_key
    [session_key, session_token]
  end

  # Return a list account item names
  def self.list_item_names
    list_items.map { |elem| elem.attributes[:label][(ACCOUNT_PREFIX.length)..-1] }
  end

  # Return a list role item names
  def self.list_role_names
    list_roles.map { |elem| elem.attributes[:label][(ROLE_PREFIX.length)..-1] }
  end

  # Return a session token if available or a static key
  def self.get_valid_item_pair(account:)
    session_key, session_token = get_pair(account: account)
    session_key, session_token = delete_expired(key: session_key, token: session_token) if session_key

    if session_key && session_token
      puts '# Using temporary session credentials'
      return session_key, session_token
    end

    item = get_item(account: account)
    if item.nil?
      warn "# Credential not found with name: #{account}"
      exit 2
    end
    [item, nil]
  end

  # Return valid creds for account
  def self.get_valid_creds(account:)
    cred, temp_cred = get_valid_item_pair(account: account)
    token = temp_cred.password unless temp_cred.nil?
    {
      account: account,
      key: cred.attributes[:account],
      secret: cred.password,
      token: token
    }
  end

  # Return a hash for account (skip tokens)
  def self.get_item_hash(account:)
    cred = get_item(account: account)
    return unless cred
    {
      account: account,
      key: cred.attributes[:account],
      secret: cred.password,
      mfa: cred.attributes[:comment]
    }
  end

  # get the ARN for a role
  def self.get_role_arn(role_name:)
    role_item = get_role(role_name: role_name)
    role_item.attributes[:account] if role_item
  end

  # Delete session token items if expired
  def self.delete_expired(key:, token:)
    expires_at = Time.at(token.attributes[:account].to_i)
    if expires_at < Time.now
      delete_pair(key: key, token: token, message: '# Removing expired session credentials')
      key = nil
      token = nil
    end
    [key, token]
  end

  # Delete session token items
  def self.delete_pair(key:, token:, message:)
    return unless key
    puts message if message
    token.delete if token
    key.delete
  end

  # Delete a session token
  def self.delete_token(account:, message:)
    session_key, session_token = get_pair(account: account)
    delete_pair(key: session_key, token: session_token, message: message)
  end

  # Delete an Account
  def self.delete_account(account:, message:)
    delete_token(account: account, message: '# Removing expired session credentials')
    cred = get_item(account: account)
    return unless cred
    puts message if message
    cred.delete
  end

  # Delete a role
  def self.delete_role(role_name:, message:)
    role = get_role(role_name: role_name)
    return unless role
    puts message if message
    role.delete
  end
end
