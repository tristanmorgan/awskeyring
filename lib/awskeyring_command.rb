require 'thor'
require 'highline'

require_relative 'awskeyring'

# AWS Key-ring command line interface.
class AwskeyringCommand < Thor
  map %w[--version -v] => :__version

  desc '--version, -v', 'Prints the version'
  def __version
    puts Awskeyring::VERSION
  end

  desc 'initialise', 'Initialises a new KEYCHAIN'
  method_option :keychain, type: :string, aliases: '-k', desc: 'Name of KEYCHAIN to initialise.'
  def initialise
    unless Awskeyring.prefs.empty?
      puts "#{Awskeyring::PREFS_FILE} exists. no need to initialise."
      exit 1
    end

    keychain ||= ask(message: "Name for new keychain (default: 'awskeyring'): ")
    keychain = 'awskeyring' if keychain.empty?

    puts 'Creating a new Keychain, you will be prompted for a password for it.'
    Awskeyring.init_keychain(awskeyring: keychain)

    puts 'Your keychain has been initialised. It will auto-lock after 5 minutes'
    puts 'and when sleeping. Use Keychain Access to adjust.'
    puts
    puts "Add accounts to your #{keychain} keychain with:"
    puts "    #{$PROGRAM_NAME} add"
  end

  desc 'list', 'Prints a list of accounts in the keyring'
  def list
    puts Awskeyring.list_item_names.join("\n")
  end

  map 'list-role' => :list_role
  desc 'list-role', 'Prints a list of roles in the keyring'
  def list_role
    puts Awskeyring.list_role_names.join("\n")
  end

  desc 'env ACCOUNT', 'Outputs bourne shell environment exports for an ACCOUNT'
  def env(account)
    cred, temp_cred = get_valid_item_pair(account: account)
    token = temp_cred.password unless temp_cred.nil?
    put_env_string(
      account: cred.attributes[:label],
      key: cred.attributes[:account],
      secret: cred.password,
      token: token
    )
  end

  desc 'add ACCOUNT', 'Adds an ACCOUNT to the keyring'
  method_option :key, type: :string, aliases: '-k', desc: 'AWS account key id.'
  method_option :secret, type: :string, aliases: '-s', desc: 'AWS account secret.'
  method_option :mfa, type: :string, aliases: '-m', desc: 'AWS virtual mfa arn.'
  def add(account)
    key ||= ask(message: '     access key id: ')
    secret ||= ask(message: ' secret_access_key: ', secure: true)
    mfa ||= ask(message: '(optional) mfa arn: ')

    Awskeyring.add_item(
      account: account,
      key: key,
      secret: secret,
      comment: mfa
    )
  end

  map 'add-role' => :add_role
  desc 'add-role ROLE', 'Adds a ROLE to the keyring'
  method_option :arn, type: :string, aliases: '-a', desc: 'AWS role arn.'
  def add_role(role)
    arn ||= ask(message: '          role arn: ')
    account ||= ask(message: '(optional) account: ')

    Awskeyring.add_role(
      role: role,
      arn: arn,
      account: account
    )
  end

  desc 'remove ACCOUNT', 'Removes an ACCOUNT from the keyring'
  def remove(account)
    cred, temp_cred = get_valid_item_pair(account: account)
    Awskeyring.delete_pair(cred, temp_cred, '# Removing credentials')
  end

  map 'remove-role' => :remove_role
  desc 'remove-role ROLE', 'Removes a ROLE from the keyring'
  def remove_role(role)
    session_key = Awskeyring.get_item("session-key #{account}")
    session_token = Awskeyring.get_item("session-token #{account}") if session_key
    Awskeyring.delete_pair(session_key, session_token, '# Removing role session') if role_key

    item_role = Awskeyring.get_role(role_name)
    Awskeyring.delete_pair(item_role, nil, "# Removing role #{role}")
  end

  desc 'awskeyring CURR PREV', 'Autocompletion for bourne shells', hide: true
  def awskeyring(curr, prev)
    comp_len = ENV['COMP_LINE'].split.length
    comp_len += 1 if curr == ''

    case comp_len
    when 2
      puts list_commands.select { |elem| elem.start_with?(curr) }.join("\n")
    when 3
      if prev == 'help'
        puts list_commands.select { |elem| elem.start_with?(curr) }.join("\n")
      else
        puts Awskeyring.list_item_names.select { |elem| elem.start_with?(curr) }.join("\n")
      end
    when 4
      puts Awskeyring.list_role_names.select { |elem| elem.start_with?(curr) }.join("\n")
    else
      exit 1
    end
  end

  private

  def list_commands
    self.class.all_commands.keys.map { |elem| elem.tr('_', '-') }
  end

  def get_valid_item_pair(account:)
    session_key = Awskeyring.get_item("session-key #{account}")
    session_token = Awskeyring.get_item("session-token #{account}") if session_key
    session_key, session_token = Awskeyring.delete_expired(session_key, session_token) if session_key

    if session_key && session_token
      puts '# Using temporary session credentials'
      return session_key, session_token
    end

    item = Awskeyring.get_item(account)
    if item.nil?
      warn "# Credential not found with name: #{account}"
      exit 2
    end
    [item, nil]
  end

  def put_env_string(account:, key:, secret:, token:)
    puts "export AWS_ACCOUNT_NAME=\"#{account}\""
    puts "export AWS_ACCESS_KEY_ID=\"#{key}\""
    puts "export AWS_ACCESS_KEY=\"#{key}\""
    puts "export AWS_SECRET_ACCESS_KEY=\"#{secret}\""
    puts "export AWS_SECRET_KEY=\"#{secret}\""
    if token
      puts "export AWS_SECURITY_TOKEN=\"#{token}\""
      puts "export AWS_SESSION_TOKEN=\"#{token}\""
    else
      puts 'unset AWS_SECURITY_TOKEN'
      puts 'unset AWS_SESSION_TOKEN'
    end
  end

  def ask(message:, secure: false)
    if secure
      HighLine.new.ask(message) { |q| q.echo = '*' }
    else
      HighLine.new.ask(message)
    end
  end
end
