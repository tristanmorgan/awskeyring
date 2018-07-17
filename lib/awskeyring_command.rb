require 'highline'
require 'thor'

require 'awskeyring'
require 'awskeyring/awsapi'
require 'awskeyring/validate'
require 'awskeyring/version'

# AWSkeyring command line interface.
class AwskeyringCommand < Thor # rubocop:disable Metrics/ClassLength
  map %w[--version -v] => :__version
  map ['init'] => :initialise
  map ['con'] => :console
  map ['ls'] => :list
  map ['lsr'] => :list_role
  map ['rm'] => :remove
  map ['rmr'] => :remove_role
  map ['rmt'] => :remove_token
  map ['rot'] => :rotate

  desc '--version, -v', 'Prints the version'
  # print the version number
  def __version
    puts Awskeyring::VERSION
  end

  desc 'initialise', 'Initialises a new KEYCHAIN'
  method_option :keychain, type: :string, aliases: '-n', desc: 'Name of KEYCHAIN to initialise.'
  # initialise the keychain
  def initialise
    unless Awskeyring.prefs.empty?
      puts "#{Awskeyring::PREFS_FILE} exists. no need to initialise."
      exit 1
    end

    keychain = ask_missing(existing: options[:keychain], message: "Name for new keychain (default: 'awskeyring')")
    keychain = 'awskeyring' if keychain.empty?

    puts 'Creating a new Keychain, you will be prompted for a password for it.'
    Awskeyring.init_keychain(awskeyring: keychain)

    exec_name = File.basename($PROGRAM_NAME)

    puts 'Your keychain has been initialised. It will auto-lock after 5 minutes'
    puts 'and when sleeping. Use Keychain Access to adjust.'
    puts
    puts "Add accounts to your #{keychain} keychain with:"
    puts "    #{exec_name} add"
  end

  desc 'list', 'Prints a list of accounts in the keyring'
  # list the accounts
  def list
    puts Awskeyring.list_account_names.join("\n")
  end

  map 'list-role' => :list_role
  desc 'list-role', 'Prints a list of roles in the keyring'
  # List roles
  def list_role
    puts Awskeyring.list_role_names.join("\n")
  end

  desc 'env ACCOUNT', 'Outputs bourne shell environment exports for an ACCOUNT'
  # Print Env vars
  def env(account = nil)
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    cred = Awskeyring.get_valid_creds(account: account)
    age_check(account, cred[:updated])
    put_env_string(
      account: cred[:account],
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token]
    )
  end

  desc 'json ACCOUNT', 'Outputs AWS CLI compatible JSON for an ACCOUNT'
  # Print JSON for use with credential_process
  def json(account = nil)
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    cred = Awskeyring.get_valid_creds(account: account)
    age_check(account, cred[:updated])
    expiry = Time.at(cred[:expiry]) unless cred[:expiry].nil?
    puts Awskeyring::Awsapi.get_cred_json(
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token],
      expiry: expiry || Time.new + 3600
    )
  end

  desc 'exec ACCOUNT command...', 'Execute a COMMAND with the environment set for an ACCOUNT'
  # execute an external command with env set
  def exec(account, *command)
    cred = Awskeyring.get_valid_creds(account: account)
    age_check(account, cred[:updated])
    env_vars = env_vars(
      account: cred[:account],
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token]
    )
    pid = Process.spawn(env_vars, command.join(' '))
    Process.wait pid
  end

  desc 'add ACCOUNT', 'Adds an ACCOUNT to the keyring'
  method_option :key, type: :string, aliases: '-k', desc: 'AWS account key id.'
  method_option :secret, type: :string, aliases: '-s', desc: 'AWS account secret.'
  method_option :mfa, type: :string, aliases: '-m', desc: 'AWS virtual mfa arn.'
  method_option :local, type: :boolean, aliases: '-l', desc: 'Only validate locally.', default: false
  method_option :update, type: :boolean, aliases: '-u', desc: 'Update existing.', default: false
  # Add an Account
  def add(account = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    key = ask_check(
      existing: options[:key], message: 'access key id', validator: Awskeyring::Validate.method(:access_key)
    )
    secret = ask_check(
      existing: options[:secret], message: 'secret access key',
      secure: true, validator: Awskeyring::Validate.method(:secret_access_key)
    )
    if options[:update]
      Awskeyring::Awsapi.verify_cred(key: key, secret: secret) unless options[:local]
      Awskeyring.update_account(
        account: account,
        key: key,
        secret: secret
      )
      puts "# Updated account #{account}"
    else
      mfa = ask_check(
        existing: options[:mfa], message: 'mfa arn', optional: true, validator: Awskeyring::Validate.method(:mfa_arn)
      )
      Awskeyring::Awsapi.verify_cred(key: key, secret: secret) unless options[:local]
      Awskeyring.add_account(
        account: account,
        key: key,
        secret: secret,
        mfa: mfa
      )
      puts "# Added account #{account}"
    end
  end

  map 'add-role' => :add_role
  desc 'add-role ROLE', 'Adds a ROLE to the keyring'
  method_option :arn, type: :string, aliases: '-a', desc: 'AWS role arn.'
  # Add a role
  def add_role(role = nil)
    role = ask_check(existing: role, message: 'role name', validator: Awskeyring::Validate.method(:role_name))
    arn = ask_check(existing: options[:arn], message: 'role arn', validator: Awskeyring::Validate.method(:role_arn))
    account = ask_check(
      existing: account, message: 'account', optional: true, validator: Awskeyring::Validate.method(:account_name)
    )

    Awskeyring.add_role(
      role: role,
      arn: arn,
      account: account
    )
    puts "# Added role #{role}"
  end

  desc 'remove ACCOUNT', 'Removes an ACCOUNT from the keyring'
  # Remove an account
  def remove(account = nil)
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    Awskeyring.delete_account(account: account, message: "# Removing account #{account}")
  end

  desc 'remove-token ACCOUNT', 'Removes a token for ACCOUNT from the keyring'
  # remove a session token
  def remove_token(account = nil)
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    Awskeyring.delete_token(account: account, message: "# Removing token for account #{account}")
  end

  map 'remove-role' => :remove_role
  desc 'remove-role ROLE', 'Removes a ROLE from the keyring'
  # remove a role
  def remove_role(role = nil)
    role = ask_check(existing: role, message: 'role name', validator: Awskeyring::Validate.method(:role_name))
    Awskeyring.delete_role(role_name: role, message: "# Removing role #{role}")
  end

  desc 'rotate ACCOUNT', 'Rotate access keys for an ACCOUNT'
  # rotate Account keys
  def rotate(account = nil) # rubocop:disable Metrics/MethodLength
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    item_hash = Awskeyring.get_account_hash(account: account)

    begin
      new_key = Awskeyring::Awsapi.rotate(
        account: item_hash[:account],
        key: item_hash[:key],
        secret: item_hash[:secret]
      )
    rescue Aws::Errors::ServiceError => err
      warn err.to_s
      exit 1
    end

    Awskeyring.update_account(
      account: account,
      key: new_key[:key],
      secret: new_key[:secret]
    )

    puts "# Updated account #{account}"
  end

  desc 'token ACCOUNT [ROLE] [MFA]', 'Create an STS Token from a ROLE or an MFA code'
  method_option :role, type: :string, aliases: '-r', desc: 'The ROLE to assume.'
  method_option :code, type: :string, aliases: '-c', desc: 'Virtual mfa CODE.'
  method_option :duration, type: :string, aliases: '-d', desc: 'Session DURATION in seconds.'
  # generate a sessiopn token
  def token(account = nil, role = nil, code = nil) # rubocop:disable all
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    role ||= options[:role]
    if role
      role = ask_check(
        existing: role, message: 'role name', validator: Awskeyring::Validate.method(:role_name)
      )
    end
    code ||= options[:code]
    if code
      code = ask_check(
        existing: code, message: 'current mfa code', validator: Awskeyring::Validate.method(:mfa_code)
      )
    end
    duration = options[:duration]
    duration ||= Awskeyring::Awsapi::ONE_HOUR.to_s if role
    duration ||= Awskeyring::Awsapi::TWELVE_HOUR.to_s if code
    duration ||= Awskeyring::Awsapi::ONE_HOUR.to_s

    item_hash = Awskeyring.get_account_hash(account: account)
    age_check(account, item_hash[:updated])
    role_arn = Awskeyring.get_role_arn(role_name: role) if role

    begin
      new_creds = Awskeyring::Awsapi.get_token(
        code: code,
        role_arn: role_arn,
        duration: duration,
        mfa: item_hash[:mfa],
        key: item_hash[:key],
        secret: item_hash[:secret],
        user: ENV['USER']
      )
      Awskeyring.delete_token(account: account, message: '# Removing STS credentials')
    rescue Aws::Errors::ServiceError => err
      warn err.to_s
      exit 1
    end

    Awskeyring.add_token(
      account: account,
      key: new_creds[:key],
      secret: new_creds[:secret],
      token: new_creds[:token],
      expiry: new_creds[:expiry].to_i.to_s,
      role: role
    )

    puts "# Token saved for account #{account}"
    puts "# Authentication valid until #{Time.at(new_creds[:expiry].to_i)}"
  end

  desc 'console ACCOUNT', 'Open the AWS Console for the ACCOUNT'
  method_option :path, type: :string, aliases: '-p', desc: 'The service PATH to open.'
  # Open the AWS Console
  def console(account = nil) # rubocop:disable Metrics/MethodLength
    account = ask_check(
      existing: account, message: 'account name', validator: Awskeyring::Validate.method(:account_name)
    )
    cred = Awskeyring.get_valid_creds(account: account)
    age_check(account, cred[:updated])

    path = options[:path] || 'console'

    begin
      login_url = Awskeyring::Awsapi.get_login_url(
        key: cred[:key],
        secret: cred[:secret],
        token: cred[:token],
        path: path,
        user: ENV['USER']
      )
    rescue Aws::Errors::ServiceError => err
      warn err.to_s
      exit 1
    end

    pid = Process.spawn("open \"#{login_url}\"")
    Process.wait pid
  end

  desc 'awskeyring CURR PREV', 'Autocompletion for bourne shells', hide: true
  # autocomplete
  def awskeyring(curr, prev)
    comp_line = ENV['COMP_LINE']
    unless comp_line
      exec_name = File.basename($PROGRAM_NAME)
      warn "enable autocomplete with 'complete -C #{$PROGRAM_NAME} #{exec_name}'"
      exit 1
    end
    comp_len = comp_line.split.index(prev)

    case prev
    when 'help'
      comp_len = 0
    when 'remove-role', '-r', 'rmr'
      comp_len = 2
    end

    print_auto_resp(curr, comp_len)
  end

  private

  def age_check(account, updated)
    age = (Time.new - updated).div 86_400
    warn "# Creds for account #{account} are #{age} days old." unless age < 90
  end

  def print_auto_resp(curr, len)
    case len
    when 0
      puts list_commands.select { |elem| elem.start_with?(curr) }.join("\n")
    when 1
      puts Awskeyring.list_account_names.select { |elem| elem.start_with?(curr) }.join("\n")
    when 2
      puts Awskeyring.list_role_names.select { |elem| elem.start_with?(curr) }.join("\n")
    else
      exit 1
    end
  end

  def list_commands
    self.class.all_commands.keys.map { |elem| elem.tr('_', '-') }
  end

  def env_vars(account:, key:, secret:, token:)
    env_var = {}
    env_var['AWS_DEFAULT_REGION'] = 'us-east-1' unless ENV['AWS_DEFAULT_REGION']
    env_var['AWS_ACCOUNT_NAME'] = account
    env_var['AWS_ACCESS_KEY_ID'] = key
    env_var['AWS_ACCESS_KEY'] = key
    env_var['AWS_SECRET_ACCESS_KEY'] = secret
    env_var['AWS_SECRET_KEY'] = secret
    if token
      env_var['AWS_SECURITY_TOKEN'] = token
      env_var['AWS_SESSION_TOKEN'] = token
    end
    env_var
  end

  def put_env_string(account:, key:, secret:, token:)
    env_var = env_vars(account: account, key: key, secret: secret, token: token)
    env_var.each { |var, value| puts "export #{var}=\"#{value}\"" }

    puts 'unset AWS_SECURITY_TOKEN' unless token
    puts 'unset AWS_SESSION_TOKEN' unless token
  end

  def ask_check(existing:, message:, secure: false, optional: false, validator: nil)
    retries ||= 3
    begin
      value = ask_missing(existing: existing, message: message, secure: secure, optional: optional)
      value = validator.call(value) unless value.empty? && optional
    rescue RuntimeError => err
      warn err.message
      existing = nil
      retry unless (retries -= 1).zero?
      exit 1
    end
    value
  end

  def ask_missing(existing:, message:, secure: false, optional: false)
    existing || ask(message: message, secure: secure, optional: optional)
  end

  def ask(message:, secure: false, optional: false)
    if secure
      HighLine.new.ask(message.rjust(20) + ': ') { |q| q.echo = '*' }
    elsif optional
      HighLine.new.ask((message + ' (optional)').rjust(20) + ': ')
    else
      HighLine.new.ask(message.rjust(20) + ': ')
    end
  end
end
