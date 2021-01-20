# frozen_string_literal: true

require 'i18n'
require 'thor'

require 'awskeyring'
require 'awskeyring/awsapi'
require 'awskeyring/input'
require 'awskeyring/validate'
require 'awskeyring/version'

# AWSkeyring command line interface.
class AwskeyringCommand < Thor # rubocop:disable Metrics/ClassLength
  I18n.load_path = Dir.glob(File.join(File.realpath(__dir__), '..', 'i18n', '*.{yml,yaml}'))
  I18n.backend.load_translations

  map %w[--version -v] => :__version
  map %w[--help -h] => :help
  map ['init'] => :initialise
  map ['adr'] => :add_role
  map ['con'] => :console
  map ['ls'] => :list
  map ['lsr'] => :list_role
  map ['rm'] => :remove
  map ['rmr'] => :remove_role
  map ['rmt'] => :remove_token
  map ['rot'] => :rotate
  map ['tok'] => :token
  map ['up'] => :update

  # default to returning an error on failure.
  def self.exit_on_failure?
    true
  end

  desc '--version, -v', I18n.t('__version.desc')
  method_option 'no-remote', type: :boolean, aliases: '-r', desc: I18n.t('method_option.noremote'), default: false
  # print the version number
  def __version
    puts "Awskeyring v#{Awskeyring::VERSION}"
    if !options['no-remote'] && Awskeyring::VERSION != Awskeyring.latest_version
      puts "the latest version v#{Awskeyring.latest_version}"
    end
    puts "Homepage #{Awskeyring::HOMEPAGE}"
  end

  desc 'initialise', I18n.t('initialise.desc')
  method_option :keychain, type: :string, aliases: '-n', desc: I18n.t('method_option.keychain')
  # initialise the keychain
  def initialise
    unless Awskeyring.prefs.empty?
      puts I18n.t('message.initialise', file: Awskeyring::PREFS_FILE)
      exit 1
    end

    keychain = ask_check(
      existing: options[:keychain],
      flags: 'optional',
      message: I18n.t('message.keychain'),
      validator: Awskeyring::Validate.method(:account_name)
    )
    keychain = 'awskeyring' if keychain.empty?

    puts I18n.t('message.newkeychain')
    Awskeyring.init_keychain(awskeyring: keychain)

    exec_name = File.basename($PROGRAM_NAME)

    puts I18n.t('message.addkeychain', keychain: keychain, exec_name: exec_name)
  end

  desc 'list', I18n.t('list.desc')
  # list the accounts
  def list
    if Awskeyring.list_account_names.empty?
      warn I18n.t('message.missing_account', bin: File.basename($PROGRAM_NAME))
      exit 1
    end
    puts Awskeyring.list_account_names.join("\n")
  end

  map 'list-role' => :list_role
  desc 'list-role', I18n.t('list_role.desc')
  method_option 'detail', type: :boolean, aliases: '-d', desc: I18n.t('method_option.detail'), default: false
  # List roles
  def list_role
    if Awskeyring.list_role_names.empty?
      warn I18n.t('message.missing_role', bin: File.basename($PROGRAM_NAME))
      exit 1
    end
    if options[:detail]
      puts Awskeyring.list_role_names_plus.join("\n")
    else
      puts Awskeyring.list_role_names.join("\n")
    end
  end

  desc 'env ACCOUNT', I18n.t('env.desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option 'unset', type: :boolean, aliases: '-u', desc: I18n.t('method_option.unset'), default: false
  # Print Env vars
  def env(account = nil)
    if options[:unset]
      put_env_string(account: nil, key: nil, secret: nil, token: nil)
    else
      account = ask_check(
        existing: account, message: I18n.t('message.account'),
        validator: Awskeyring.method(:account_exists),
        limited_to: Awskeyring.list_account_names
      )
      cred = age_check_and_get(account: account, no_token: options['no-token'])
      put_env_string(cred)
    end
  end

  desc 'json ACCOUNT', I18n.t('json.desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  # Print JSON for use with credential_process
  def json(account)
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

  desc 'import ACCOUNT', I18n.t('import.desc')
  method_option 'no-remote', type: :boolean, aliases: '-r', desc: I18n.t('method_option.noremote'), default: false
  # Import an Account
  def import(account = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_not_exists)
    )
    new_creds = Awskeyring::Awsapi.get_credentials_from_file(account: account)
    unless options['no-remote']
      Awskeyring::Awsapi.verify_cred(
        key: new_creds[:key],
        secret: new_creds[:secret],
        token: new_creds[:token]
      )
    end
    if new_creds[:token].nil?
      Awskeyring.add_account(
        account: new_creds[:account],
        key: new_creds[:key],
        secret: new_creds[:secret],
        mfa: ''
      )
      puts I18n.t('message.addaccount', account: account)
    else
      Awskeyring.add_token(
        account: new_creds[:account],
        key: new_creds[:key],
        secret: new_creds[:secret],
        token: new_creds[:token],
        expiry: new_creds[:expiry].to_i.to_s,
        role: nil
      )
      puts I18n.t('message.addtoken', account: account, time: Time.at(new_creds[:expiry].to_i))
    end
  end

  desc 'exec ACCOUNT command...', I18n.t('exec.desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option 'no-bundle', type: :boolean, aliases: '-b', desc: I18n.t('method_option.nobundle'), default: false
  # execute an external command with env set
  def exec(account, *command)
    if command.empty?
      warn I18n.t('message.exec')
      exit 1
    end
    cred = age_check_and_get(account: account, no_token: options['no-token'])
    env_vars = Awskeyring::Awsapi.get_env_array(cred)
    unbundle if options['no-bundle']
    begin
      pid = Process.spawn(env_vars, command.join(' '))
      Process.wait pid
      $CHILD_STATUS
    rescue Errno::ENOENT => e
      warn e.to_s
      exit 1
    end
  end

  desc 'add ACCOUNT', I18n.t('add.desc')
  method_option :key, type: :string, aliases: '-k', desc: I18n.t('method_option.key')
  method_option :secret, type: :string, aliases: '-s', desc: I18n.t('method_option.secret')
  method_option :mfa, type: :string, aliases: '-m', desc: I18n.t('method_option.mfa')
  method_option 'no-remote', type: :boolean, aliases: '-r', desc: I18n.t('method_option.noremote'), default: false
  # Add an Account
  def add(account = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_not_exists)
    )
    key = ask_check(
      existing: options[:key], message: I18n.t('message.key'), validator: Awskeyring.method(:access_key_not_exists)
    )
    secret = ask_check(
      existing: options[:secret], message: I18n.t('message.secret'),
      flags: 'secure', validator: Awskeyring::Validate.method(:secret_access_key)
    )
    mfa = ask_check(
      existing: options[:mfa], message: I18n.t('message.mfa'),
      flags: 'optional', validator: Awskeyring::Validate.method(:mfa_arn)
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
  def update(account = nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    account = ask_check(
      existing: account, message: I18n.t('message.account'),
      validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
    key = ask_check(
      existing: options[:key], message: I18n.t('message.key'), validator: Awskeyring.method(:access_key_not_exists)
    )
    secret = ask_check(
      existing: options[:secret], message: I18n.t('message.secret'),
      flags: 'secure', validator: Awskeyring::Validate.method(:secret_access_key)
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
      validator: Awskeyring.method(:role_not_exists)
    )
    arn = ask_check(
      existing: options[:arn], message: I18n.t('message.arn'),
      validator: Awskeyring.method(:role_arn_not_exists)
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
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
    Awskeyring.delete_account(account: account, message: I18n.t('message.delaccount', account: account))
  end

  desc 'remove-token ACCOUNT', I18n.t('remove_token.desc')
  # remove a session token
  def remove_token(account = nil)
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:token_exists),
      limited_to: Awskeyring.list_token_names
    )
    Awskeyring.delete_token(account: account, message: I18n.t('message.deltoken', account: account))
  end

  map 'remove-role' => :remove_role
  desc 'remove-role ROLE', I18n.t('remove_role.desc')
  # remove a role
  def remove_role(role = nil)
    role = ask_check(
      existing: role, message: I18n.t('message.role'), validator: Awskeyring.method(:role_exists),
      limited_to: Awskeyring.list_role_names
    )
    Awskeyring.delete_role(role_name: role, message: I18n.t('message.delrole', role: role))
  end

  desc 'rotate ACCOUNT', I18n.t('rotate.desc')
  # rotate Account keys
  def rotate(account = nil) # rubocop:disable Metrics/MethodLength
    account = ask_check(
      existing: account,
      message: I18n.t('message.account'),
      validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
    cred = Awskeyring.get_valid_creds(account: account, no_token: true)

    begin
      new_key = Awskeyring::Awsapi.rotate(
        account: cred[:account],
        key: cred[:key],
        secret: cred[:secret],
        key_message: I18n.t('message.rotate', account: account)
      )
    rescue Aws::Errors::ServiceError => e
      warn e.to_s
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
  def token(account = nil, role = nil, code = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    account = ask_check(
      existing: account,
      message: I18n.t('message.account'),
      validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
    role ||= options[:role]
    if role
      role = ask_check(
        existing: role, message: I18n.t('message.role'), validator: Awskeyring.method(:role_exists),
        limited_to: Awskeyring.list_role_names
      )
    end
    code ||= options[:code]
    if code
      code = ask_check(
        existing: code, message: I18n.t('message.code'), validator: Awskeyring::Validate.method(:mfa_code)
      )
    end
    item_hash = age_check_and_get(account: account, no_token: true)

    begin
      new_creds = Awskeyring::Awsapi.get_token(
        code: code,
        role_arn: (Awskeyring.get_role_arn(role_name: role) if role),
        duration: default_duration(options[:duration], role, code),
        mfa: item_hash[:mfa],
        key: item_hash[:key],
        secret: item_hash[:secret],
        user: ENV['USER']
      )
      Awskeyring.delete_token(account: account, message: '# Removing STS credentials')
    rescue Aws::Errors::ServiceError => e
      warn e.to_s
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
  method_option :browser, type: :string, aliases: '-b', desc: I18n.t('method_option.browser')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option 'no-open', type: :boolean, aliases: '-o', desc: I18n.t('method_option.noopen'), default: false
  # Open the AWS Console
  def console(account = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    account = ask_check(
      existing: account,
      message: I18n.t('message.account'),
      validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
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
    rescue Aws::Errors::ServiceError => e
      warn e.to_s
      exit 1
    end

    if options['no-open']
      puts login_url
    else
      spawn_cmd = options[:browser] ? "open -a \"#{options[:browser]}\" \"#{login_url}\"" : "open \"#{login_url}\""
      pid = Process.spawn(spawn_cmd)
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
    when 'help', File.basename($PROGRAM_NAME)
      comp_len = 0
    when 'remove-role', '-r', 'rmr'
      comp_len = 2
    when '--path', '-p'
      comp_len = 40
    when 'remove-token', 'rmt'
      comp_len = 50
    when '--browser', '-b'
      comp_len = 60
    end

    [curr, comp_len, sub_cmd]
  end

  def sub_command(comp_lines)
    return nil if comp_lines.nil? || comp_lines.length < 2

    sub_cmd = comp_lines[1]

    return sub_cmd if self.class.all_commands.keys.index(sub_cmd)

    self.class.map[sub_cmd].to_s
  end

  def print_auto_resp(curr, len, sub_cmd) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    list = []
    case len
    when 0
      list = list_commands
    when 1
      list = Awskeyring.list_account_names
    when 2
      list = Awskeyring.list_role_names
    when 3..10
      list = list_arguments(command: sub_cmd)
    when 40
      list = Awskeyring.list_console_path
    when 50
      list = Awskeyring.list_token_names
    when 60
      list = Awskeyring.list_browsers
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

  def put_env_string(cred)
    env_var = Awskeyring::Awsapi.get_env_array(cred)
    env_var.each { |var, value| puts "export #{var}=\"#{value}\"" }
    Awskeyring::Awsapi::AWS_ENV_VARS.each { |key| puts "unset #{key}" unless env_var.key?(key) }
  end

  def default_duration(duration, role, code)
    duration ||= Awskeyring::Awsapi::ONE_HOUR.to_s if role
    duration ||= Awskeyring::Awsapi::TWELVE_HOUR.to_s if code
    duration || Awskeyring::Awsapi::ONE_HOUR.to_s
  end

  def ask_check(existing:, message:, flags: nil, validator: nil, limited_to: nil) # rubocop:disable Metrics/MethodLength
    retries ||= 3
    begin
      value = ask_missing(
        existing: existing,
        message: message,
        secure: 'secure'.eql?(flags),
        optional: 'optional'.eql?(flags),
        limited_to: limited_to
      )
      value = validator.call(value) unless value.empty? && 'optional'.eql?(flags)
    rescue RuntimeError => e
      warn e.message
      existing = nil
      retry unless (retries -= 1).zero?
      exit 1
    end
    value
  end

  def ask_missing(existing:, message:, secure: false, optional: false, limited_to: nil)
    existing || ask(message: message, secure: secure, optional: optional, limited_to: limited_to).strip
  end

  def ask(message:, secure: false, optional: false, limited_to: nil)
    if secure
      Awskeyring::Input.read_secret("#{message.rjust(20)}: ")
    elsif optional
      Thor::LineEditor.readline("#{"#{message} (optional)".rjust(20)}: ")
    elsif limited_to
      Thor::LineEditor.readline("#{message.rjust(20)}: ", limited_to: limited_to)
    else
      Thor::LineEditor.readline("#{message.rjust(20)}: ")
    end
  end

  def unbundle
    to_delete = ENV.keys.select { |elem| elem.start_with?('BUNDLER_ORIG_') }
    bundled_env = to_delete.map { |elem| elem[('BUNDLER_ORIG_'.length)..] }
    to_delete << 'BUNDLE_GEMFILE'
    bundled_env.each do |env_name|
      ENV[env_name] = ENV["BUNDLER_ORIG_#{env_name}"]
      to_delete << env_name if ENV["BUNDLER_ORIG_#{env_name}"].start_with? 'BUNDLER_'
    end
    to_delete.each do |env_name|
      ENV.delete(env_name)
    end
  end
end
