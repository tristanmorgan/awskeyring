require 'i18n'
require 'thor'

require 'awskeyring'
require 'awskeyring/awsapi'
require 'awskeyring/validate'
require 'awskeyring/version'

# AWSkeyring command line interface.
class AwskeyringCommand < Thor # rubocop:disable Metrics/ClassLength
  I18n.load_path = Dir.glob(File.join(File.realpath(__dir__), '..', 'i18n', '*.{yml,yaml}'))
  I18n.backend.load_translations

  map %w[--version -v] => :__version
  map ['init'] => :initialise
  map ['con'] => :console
  map ['ls'] => :list
  map ['lsr'] => :list_role
  map ['rm'] => :remove
  map ['rmr'] => :remove_role
  map ['rmt'] => :remove_token
  map ['rot'] => :rotate
  map ['tok'] => :token
  map ['up'] => :update

  desc '--version, -v', I18n.t('__version.desc')
  # print the version number
  def __version
    puts Awskeyring::VERSION
  end

  desc 'initialise', I18n.t('initialise.desc')
  method_option :keychain, type: :string, aliases: '-n', desc: I18n.t('method_option.keychain')
  # initialise the keychain
  def initialise
    unless Awskeyring.prefs.empty?
      puts I18n.t('message.initialise', file: Awskeyring::PREFS_FILE)
      exit 1
    end

    keychain = ask_missing(existing: options[:keychain], message: I18n.t('message.keychain'))
    keychain = 'awskeyring' if keychain.empty?

    puts I18n.t('message.newkeychain')
    Awskeyring.init_keychain(awskeyring: keychain)

    exec_name = File.basename($PROGRAM_NAME)

    puts I18n.t('message.addkeychain', keychain: keychain, exec_name: exec_name)
  end

  desc 'list', I18n.t('list.desc')
  # list the accounts
  def list
    puts Awskeyring.list_account_names.join("\n")
  end

  map 'list-role' => :list_role
  desc 'list-role', I18n.t('list_role.desc')
  # List roles
  def list_role
    puts Awskeyring.list_role_names.join("\n")
  end

  desc 'env ACCOUNT', I18n.t('env.desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  # Print Env vars
  def env(account = nil)
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    cred = age_check_and_get(account: account, no_token: options['no-token'])
    put_env_string(
      account: cred[:account],
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token]
    )
  end

  desc 'json ACCOUNT', I18n.t('json.desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  # Print JSON for use with credential_process
  def json(account = nil)
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    cred = age_check_and_get(account: account, no_token: options['no-token'])
    expiry = Time.at(cred[:expiry]) unless cred[:expiry].nil?
    puts Awskeyring::Awsapi.get_cred_json(
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token],
      expiry: (expiry || Time.new + Awskeyring::Awsapi::ONE_HOUR).iso8601
    )
  end

  desc 'exec ACCOUNT command...', I18n.t('exec.desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  # execute an external command with env set
  def exec(account, *command)
    cred = age_check_and_get(account: account, no_token: options['no-token'])
    env_vars = env_vars(
      account: cred[:account],
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token]
    )
    pid = Process.spawn(env_vars, command.join(' '))
    Process.wait pid
  end

  desc 'add ACCOUNT', I18n.t('add.desc')
  method_option :key, type: :string, aliases: '-k', desc: I18n.t('method_option.key')
  method_option :secret, type: :string, aliases: '-s', desc: I18n.t('method_option.secret')
  method_option :mfa, type: :string, aliases: '-m', desc: I18n.t('method_option.mfa')
  method_option 'no-remote', type: :boolean, aliases: '-r', desc: I18n.t('method_option.noremote'), default: false
  # Add an Account
  def add(account = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring::Validate.method(:account_name)
    )
    key = ask_check(
      existing: options[:key], message: I18n.t('message.key'), validator: Awskeyring::Validate.method(:access_key)
    )
    secret = ask_check(
      existing: options[:secret], message: I18n.t('message.secret'),
      secure: true, validator: Awskeyring::Validate.method(:secret_access_key)
    )
    mfa = ask_check(
      existing: options[:mfa], message: I18n.t('message.mfa'),
      optional: true, validator: Awskeyring::Validate.method(:mfa_arn)
    )
    Awskeyring::Awsapi.verify_cred(key: key, secret: secret) unless options['no-remote']
    Awskeyring.add_account(
      account: account,
      key: key,
      secret: secret,
      mfa: mfa
    )
    puts I18n.t('message.addaccount', account: account)
  end

  desc 'update ACCOUNT', I18n.t('update.desc')
  method_option :key, type: :string, aliases: '-k', desc: I18n.t('method_option.key')
  method_option :secret, type: :string, aliases: '-s', desc: I18n.t('method_option.secret')
  method_option 'no-remote', type: :boolean, aliases: '-r', desc: I18n.t('method_option.noremote'), default: false
  # Update an Account
  def update(account = nil) # rubocop:disable Metrics/MethodLength
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    key = ask_check(
      existing: options[:key], message: I18n.t('message.key'), validator: Awskeyring::Validate.method(:access_key)
    )
    secret = ask_check(
      existing: options[:secret], message: I18n.t('message.secret'),
      secure: true, validator: Awskeyring::Validate.method(:secret_access_key)
    )
    Awskeyring::Awsapi.verify_cred(key: key, secret: secret) unless options['no-remote']
    Awskeyring.update_account(
      account: account,
      key: key,
      secret: secret
    )
    puts I18n.t('message.upaccount', account: account)
  end

  map 'add-role' => :add_role
  desc 'add-role ROLE', I18n.t('add_role.desc')
  method_option :arn, type: :string, aliases: '-a', desc: I18n.t('method_option.arn')
  # Add a role
  def add_role(role = nil)
    role = ask_check(
      existing: role, message: I18n.t('message.role'),
      validator: Awskeyring::Validate.method(:role_name)
    )
    arn = ask_check(
      existing: options[:arn], message: I18n.t('message.arn'),
      validator: Awskeyring::Validate.method(:role_arn)
    )

    Awskeyring.add_role(
      role: role,
      arn: arn
    )
    puts I18n.t('message.addrole', role: role)
  end

  desc 'remove ACCOUNT', I18n.t('remove.desc')
  # Remove an account
  def remove(account = nil)
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    Awskeyring.delete_account(account: account, message: I18n.t('message.delaccount', account: account))
  end

  desc 'remove-token ACCOUNT', I18n.t('remove_token.desc')
  # remove a session token
  def remove_token(account = nil)
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    Awskeyring.delete_token(account: account, message: I18n.t('message.deltoken', account: account))
  end

  map 'remove-role' => :remove_role
  desc 'remove-role ROLE', I18n.t('remove_role.desc')
  # remove a role
  def remove_role(role = nil)
    role = ask_check(
      existing: role, message: I18n.t('message.role'), validator: Awskeyring::Validate.method(:role_name)
    )
    Awskeyring.delete_role(role_name: role, message: I18n.t('message.delrole', role: role))
  end

  desc 'rotate ACCOUNT', I18n.t('rotate.desc')
  # rotate Account keys
  def rotate(account = nil) # rubocop:disable Metrics/MethodLength
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    cred = Awskeyring.get_valid_creds(account: account, no_token: true)

    begin
      new_key = Awskeyring::Awsapi.rotate(
        account: cred[:account],
        key: cred[:key],
        secret: cred[:secret],
        key_message: I18n.t('message.rotate', account: account)
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

    puts I18n.t('message.upaccount', account: account)
  end

  desc 'token ACCOUNT [ROLE] [MFA]', I18n.t('token.desc')
  method_option :role, type: :string, aliases: '-r', desc: I18n.t('method_option.role')
  method_option :code, type: :string, aliases: '-c', desc: I18n.t('method_option.code')
  method_option :duration, type: :string, aliases: '-d', desc: I18n.t('method_option.duration')
  # generate a sessiopn token
  def token(account = nil, role = nil, code = nil) # rubocop:disable all
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    role ||= options[:role]
    if role
      role = ask_check(
        existing: role, message: I18n.t('message.role'), validator: Awskeyring::Validate.method(:role_name)
      )
    end
    code ||= options[:code]
    if code
      code = ask_check(
        existing: code, message: I18n.t('message.code'), validator: Awskeyring::Validate.method(:mfa_code)
      )
    end
    duration = options[:duration]
    duration ||= Awskeyring::Awsapi::ONE_HOUR.to_s if role
    duration ||= Awskeyring::Awsapi::TWELVE_HOUR.to_s if code
    duration ||= Awskeyring::Awsapi::ONE_HOUR.to_s

    item_hash = age_check_and_get(account: account, no_token: true)
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

    puts I18n.t('message.addtoken', account: account, time: Time.at(new_creds[:expiry].to_i))
  end

  desc 'console ACCOUNT', I18n.t('console.desc')
  method_option :path, type: :string, aliases: '-p', desc: I18n.t('method_option.path')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option 'no-open', type: :boolean, aliases: '-o', desc: I18n.t('method_option.noopen'), default: false
  # Open the AWS Console
  def console(account = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists)
    )
    cred = age_check_and_get(account: account, no_token: options['no-token'])

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

    if options['no-open']
      puts login_url
    else
      pid = Process.spawn("open \"#{login_url}\"")
      Process.wait pid
    end
  end

  desc 'awskeyring CURR PREV', I18n.t('awskeyring.desc'), hide: true
  # autocomplete
  def awskeyring(curr, prev)
    comp_line = ENV['COMP_LINE']
    unless comp_line
      exec_name = File.basename($PROGRAM_NAME)
      warn I18n.t('message.awskeyring', path: $PROGRAM_NAME, bin: exec_name)
      exit 1
    end

    curr, comp_len, sub_cmd = comp_type(comp_line: comp_line, curr: curr, prev: prev)
    print_auto_resp(curr, comp_len, sub_cmd)
  end

  private

  def age_check_and_get(account:, no_token:)
    cred = Awskeyring.get_valid_creds(account: account, no_token: no_token)

    maxage = Awskeyring.key_age
    age = (Time.new - cred[:updated]).div Awskeyring::Awsapi::ONE_DAY
    warn I18n.t('message.age_check', account: account, age: age) unless age < maxage

    cred
  end

  def comp_type(comp_line:, curr:, prev:)
    comp_len = comp_line.split.index(prev)
    sub_cmd = sub_command(comp_line.split)

    comp_len = 3 if curr.start_with?('-')

    case prev
    when 'help'
      comp_len = 0
    when 'remove-role', '-r', 'rmr'
      comp_len = 2
    when '--path', '-p'
      comp_len = 4
    end

    [curr, comp_len, sub_cmd]
  end

  def sub_command(comp_lines)
    return nil if comp_lines.nil? || comp_lines.length < 2

    sub_cmd = comp_lines[1]

    return sub_cmd if self.class.all_commands.keys.index(sub_cmd)

    self.class.map[sub_cmd].to_s
  end

  def print_auto_resp(curr, len, sub_cmd)
    list = []
    case len
    when 0
      list = list_commands
    when 1
      list = Awskeyring.list_account_names
    when 2
      list = Awskeyring.list_role_names
    when 3
      list = list_arguments(command: sub_cmd)
    when 4
      list = Awskeyring.list_console_path
    else
      exit 1
    end
    puts list.select { |elem| elem.start_with?(curr) }.sort!.join("\n")
  end

  def list_commands
    self.class.all_commands.keys.map { |elem| elem.tr('_', '-') }.reject! { |elem| elem == 'awskeyring' }
  end

  def list_arguments(command:)
    exit 1 if command.empty?
    self.class.all_commands[command].options.values.map(&:aliases).flatten! +
      self.class.all_commands[command].options.values.map(&:switch_name)
  end

  def env_vars(account:, key:, secret:, token:)
    env_var = {}
    env_var['AWS_DEFAULT_REGION'] = 'us-east-1' unless Awskeyring::Awsapi.region
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
      Thor::LineEditor.readline(message.rjust(20) + ': ', echo: false).strip
    elsif optional
      Thor::LineEditor.readline((message + ' (optional)').rjust(20) + ': ')
    else
      Thor::LineEditor.readline(message.rjust(20) + ': ')
    end
  end
end
