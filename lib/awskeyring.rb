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
  # Default warning of key age in days.
  DEFAULT_KEY_AGE = 90
  # Default Console Paths
  DEFAULT_CONSOLE_LIST = %w[cloudformation ec2/v2 iam rds route53 s3 sns sqs vpc].freeze

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

    prefs = {
      awskeyring: awskeyring,
      keyage: DEFAULT_KEY_AGE,
      console: DEFAULT_CONSOLE_LIST
    }
    File.new(Awskeyring::PREFS_FILE, 'w').write JSON.dump(prefs)
  end

  # Load the keychain for access
  #
  # @return [Keychain] keychain ready for use.
  private_class_method def self.load_keychain
    unless File.exist?(Awskeyring::PREFS_FILE) && !prefs.empty?
      warn I18n.t('message.missing', bin: File.basename($PROGRAM_NAME))
      exit 1
    end

    keychain = Keychain.open(prefs['awskeyring'])
    warn I18n.t('message.timeout') if keychain && keychain.lock_interval > 300

    keychain
  end

  # Return a list of all acount items
  private_class_method def self.list_items
    items = all_items.all.sort do |elem_a, elem_b|
      elem_a.attributes[:label] <=> elem_b.attributes[:label]
    end
    items.select { |elem| elem.attributes[:label].start_with?(ACCOUNT_PREFIX) }
  end

  # Return a list of all role items
  private_class_method def self.list_roles
    items = all_items.all.sort do |elem_a, elem_b|
      elem_a.attributes[:label] <=> elem_b.attributes[:label]
    end
    items.select { |elem| elem.attributes[:label].start_with?(ROLE_PREFIX) }
  end

  # Return all keychain items
  private_class_method def self.all_items
    load_keychain.generic_passwords
  end

  # Add an account item
  def self.add_account(account:, key:, secret:, mfa:)
    all_items.create(
      label: ACCOUNT_PREFIX + account,
      account: key,
      password: secret,
      comment: mfa
    )
  end

  # update and account item
  def self.update_account(account:, key:, secret:)
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
  def self.add_token(params = {})
    all_items.create(label: SESSION_KEY_PREFIX + params[:account],
                     account: params[:key],
                     password: params[:secret],
                     comment: params[:role].nil? ? '' : ROLE_PREFIX + params[:role])
    all_items.create(label: SESSION_TOKEN_PREFIX + params[:account],
                     account: params[:expiry],
                     password: params[:token],
                     comment: params[:role] || '')
  end

  # Return an account item by name
  private_class_method def self.get_item(account:)
    all_items.where(label: ACCOUNT_PREFIX + account).first
  end

  # Return a role item by name
  private_class_method def self.get_role(role_name:)
    all_items.where(label: ROLE_PREFIX + role_name).first
  end

  # Return a session token pair of items by name
  private_class_method def self.get_token_pair(account:)
    session_key = all_items.where(label: SESSION_KEY_PREFIX + account).first
    session_token = all_items.where(label: SESSION_TOKEN_PREFIX + account).first if session_key
    [session_key, session_token]
  end

  # Return a list account item names
  def self.list_account_names
    list_items.map { |elem| elem.attributes[:label][(ACCOUNT_PREFIX.length)..-1] }
  end

  # Return a list role item names
  def self.list_role_names
    list_roles.map { |elem| elem.attributes[:label][(ROLE_PREFIX.length)..-1] }
  end

  # Return a list of console paths
  def self.list_console_path
    prefs.key?('console') ? prefs['console'] : DEFAULT_CONSOLE_LIST
  end

  # Return Key age warning number
  def self.key_age
    prefs.key?('keyage') ? prefs['keyage'] : DEFAULT_KEY_AGE
  end

  # Return a session token if available or a static key
  private_class_method def self.get_valid_item_pair(account:, no_token: false)
    session_key, session_token = get_token_pair(account: account)
    session_key, session_token = delete_expired(key: session_key, token: session_token) if session_key

    if session_key && session_token && !no_token
      puts I18n.t('message.temporary')
      return session_key, session_token
    end

    item = get_item(account: account)
    if item.nil?
      warn I18n.t('message.notfound', account: account)
      exit 2
    end
    [item, nil]
  end

  # Return valid creds for account
  def self.get_valid_creds(account:, no_token: false)
    cred, temp_cred = get_valid_item_pair(account: account, no_token: no_token)
    token = temp_cred.password unless temp_cred.nil?
    expiry = temp_cred.attributes[:account].to_i unless temp_cred.nil?
    {
      account: account,
      expiry: expiry,
      key: cred.attributes[:account],
      mfa: no_token ? cred.attributes[:comment] : nil,
      secret: cred.password,
      token: token,
      updated: cred.attributes[:updated_at]
    }
  end

  # get the ARN for a role
  def self.get_role_arn(role_name:)
    role_item = get_role(role_name: role_name)
    role_item.attributes[:account] if role_item
  end

  # Delete session token items if expired
  private_class_method def self.delete_expired(key:, token:)
    expires_at = Time.at(token.attributes[:account].to_i)
    if expires_at < Time.now
      delete_pair(key: key, token: token, message: I18n.t('message.delexpired'))
      key = nil
      token = nil
    end
    [key, token]
  end

  # Delete session token items
  private_class_method def self.delete_pair(key:, token:, message:)
    return unless key

    puts message if message
    token.delete if token
    key.delete
  end

  # Delete a session token
  def self.delete_token(account:, message:)
    session_key, session_token = get_token_pair(account: account)
    delete_pair(key: session_key, token: session_token, message: message)
  end

  # Delete an Account
  def self.delete_account(account:, message:)
    delete_token(account: account, message: I18n.t('message.delexpired'))
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
