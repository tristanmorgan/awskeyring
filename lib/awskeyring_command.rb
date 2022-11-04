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
  package_name 'Awskeyring'
  I18n.load_path = Dir.glob(File.join(File.realpath(__dir__), '..', 'i18n', '*.{yml,yaml}'))
  I18n.backend.load_translations

  map %w[--version -v] => :__version
  map 'adr' => :add_role
  map 'assume-role' => :token
  map 'ls' => :list
  map 'lsr' => :list_role
  map 'rm' => :remove
  map 'rmr' => :remove_role
  map 'rmt' => :remove_token
  default_command :default

  # default to returning an error on failure.
  def self.exit_on_failure?
    true
  end

  desc 'default', I18n.t('default_desc'), hide: true
  # default command to run
  def default
    if Awskeyring.prefs.empty?
      invoke :initialise
    else
      invoke :help
    end
  end

  desc '--version, -v', I18n.t('__version_desc')
  method_option 'no-remote', type: :boolean, aliases: '-r', desc: I18n.t('method_option.noremote'), default: false
  # print the version number
  def __version
    puts "Awskeyring v#{Awskeyring::VERSION}"
    if !options['no-remote'] && Awskeyring::VERSION != Awskeyring.latest_version
      puts "the latest version v#{Awskeyring.latest_version}"
    end
    puts "Homepage #{Awskeyring::HOMEPAGE}"
  end

  desc 'initialise', I18n.t('initialise_desc')
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

  desc 'list', I18n.t('list_desc')
  # list the accounts
  def list
    if Awskeyring.list_account_names.empty?
      warn I18n.t('message.missing_account', bin: File.basename($PROGRAM_NAME))
      exit 1
    end
    puts Awskeyring.list_account_names.join("\n")
  end

  desc 'list-role', I18n.t('list_role_desc')
  method_option :detail, type: :boolean, aliases: '-d', desc: I18n.t('method_option.detail'), default: false
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

  desc 'env ACCOUNT', I18n.t('env_desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option :unset, type: :boolean, aliases: '-u', desc: I18n.t('method_option.unset'), default: false
  method_option :force, type: :boolean, aliases: '-f', desc: I18n.t('method_option.force'), default: false
  # Print Env vars
  def env(account = nil)
    if options[:unset]
      put_env_string(account: nil, key: nil, secret: nil, token: nil)
    else
      if $stdout.isatty && !options[:force]
        warn I18n.t('message.ttyblock')
        exit 1
      end
      account = ask_check(
        existing: account, message: I18n.t('message.account'),
        validator: Awskeyring.method(:account_exists),
        limited_to: Awskeyring.list_account_names
      )
      cred = age_check_and_get(account: account, no_token: options['no-token'])
      put_env_string(cred)
    end
  end

  desc 'json ACCOUNT', I18n.t('json_desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option :force, type: :boolean, aliases: '-f', desc: I18n.t('method_option.force'), default: false
  # Print JSON for use with credential_process
  def json(account) # rubocop:disable Metrics/AbcSize
    if $stdout.isatty && !options[:force]
      warn I18n.t('message.ttyblock')
      exit 1
    end
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
    cred = age_check_and_get(account: account, no_token: options['no-token'])
    expiry = Time.at(cred[:expiry]) unless cred[:expiry].nil?
    puts Awskeyring::Awsapi.get_cred_json(
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token],
      expiry: (expiry || (Time.new + Awskeyring::Awsapi::ONE_HOUR)).iso8601
    )
  end

  desc 'import ACCOUNT', I18n.t('import_desc')
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

  desc 'exec ACCOUNT command...', I18n.t('exec_desc')
  method_option 'no-token', type: :boolean, aliases: '-n', desc: I18n.t('method_option.notoken'), default: false
  method_option 'no-bundle', type: :boolean, aliases: '-b', desc: I18n.t('method_option.nobundle'), default: false
  # execute an external command with env set
  def exec(account, *command) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    if command.empty?
      warn I18n.t('message.exec')
      exit 1
    end
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
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

  desc 'add ACCOUNT', I18n.t('add_desc')
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

  desc 'update ACCOUNT', I18n.t('update_desc')
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

  desc 'add-role ROLE', I18n.t('add_role_desc')
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

  desc 'remove ACCOUNT', I18n.t('remove_desc')
  # Remove an account
  def remove(account = nil)
    account = ask_check(
      existing: account, message: I18n.t('message.account'), validator: Awskeyring.method(:account_exists),
      limited_to: Awskeyring.list_account_names
    )
    Awskeyring.delete_account(account: account, message: I18n.t('message.delaccount', account: account))
  end

  desc 'remove-token ACCOUNT', I18n.t('remove_token_desc')
  # remove a session token
  def remove_token(token = nil)
    token = ask_check(
      existing: token, message: I18n.t('message.account'), validator: Awskeyring.method(:token_exists),
      limited_to: Awskeyring.list_token_names
    )
    Awskeyring.delete_token(account: token, message: I18n.t('message.deltoken', account: token))
  end

  desc 'remove-role ROLE', I18n.t('remove_role_desc')
  # remove a role
  def remove_role(role = nil)
    role = ask_check(
      existing: role, message: I18n.t('message.role'), validator: Awskeyring.method(:role_exists),
      limited_to: Awskeyring.list_role_names
    )
    Awskeyring.delete_role(role_name: role, message: I18n.t('message.delrole', role: role))
  end

  desc 'rotate ACCOUNT', I18n.t('rotate_desc')
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

  desc 'token ACCOUNT [ROLE] [CODE]', I18n.t('token_desc')
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

    new_creds = Awskeyring::Awsapi.get_token(
      code: code,
      role_arn: (Awskeyring.get_role_arn(role_name: role) if role),
      duration: default_duration(options[:duration], role, code),
      mfa: item_hash[:mfa],
      key: item_hash[:key],
      secret: item_hash[:secret],
      user: ENV.fetch('USER', 'awskeyring')
    )
    Awskeyring.delete_token(account: account, message: '# Removing STS credentials')

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

  desc 'console ACCOUNT', I18n.t('console_desc')
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

    login_url = Awskeyring::Awsapi.get_login_url(
      key: cred[:key],
      secret: cred[:secret],
      token: cred[:token],
      path: path,
      user: ENV.fetch('USER', 'awskeyring')
    )

    if options['no-open']
      puts login_url
    else
      spawn_cmd = options[:browser] ? "open -a \"#{options[:browser]}\" \"#{login_url}\"" : "open \"#{login_url}\""
      pid = Process.spawn(spawn_cmd)
      Process.wait pid
    end
  end

  desc "#{File.basename($PROGRAM_NAME)} CURR PREV", I18n.t('awskeyring_desc'), hide: true
  map File.basename($PROGRAM_NAME) => :autocomplete
  # autocomplete
  def autocomplete(curr, prev = nil)
    curr, prev = fix_args(curr, prev)
    comp_line = ENV.fetch('COMP_LINE', nil)
    comp_point_str = ENV.fetch('COMP_POINT', nil)
    unless comp_line && comp_point_str
      exec_name = File.basename($PROGRAM_NAME)
      warn I18n.t('message.awskeyring', path: $PROGRAM_NAME, bin: exec_name)
      exit 1
    end

    comp_lines = comp_line[0..(comp_point_str.to_i)].split

    comp_type, sub_cmd = comp_type(comp_lines: comp_lines, prev: prev)
    list = fetch_auto_resp(comp_type, sub_cmd)
    puts list.select { |elem| elem.start_with?(curr) }.sort!.join("\n")
  end

  private

  # when a double dash is parsed it is dropped from the args but we need it
  def fix_args(curr, prev)
    if prev.nil?
      [ARGV[1], ARGV[2]]
    else
      [curr, prev]
    end
  end

  # determine the type of completion needed
  def comp_type(comp_lines:, prev:)
    sub_cmd = sub_command(comp_lines)
    comp_idx = comp_lines.rindex(prev)

    case prev
    when '--path', '-p'
      comp_type = :path_type
    when '--browser', '-b'
      comp_type = :browser_type
    else
      comp_type = :command
      comp_type = param_type(comp_idx, sub_cmd) unless sub_cmd.empty?
    end

    [comp_type, sub_cmd]
  end

  # check params for named params or fall back to flags
  def param_type(comp_idx, sub_cmd)
    types = %i[opt req]
    param_list = method(sub_cmd).parameters.select { |elem| types.include? elem[0] }
    if comp_idx.zero?
      :command
    elsif comp_idx > param_list.length
      :flag
    else
      param_list[comp_idx - 1][1]
    end
  end

  # catch the command from prefixes and aliases
  def sub_command(comp_lines)
    return '' if comp_lines.length < 2

    sub_cmd = comp_lines[1]

    return self.class.map[sub_cmd].to_s if self.class.map.key? sub_cmd

    (Awskeyring.solo_select(list_commands, sub_cmd) || '').tr('-', '_')
  end

  # given a type return the right list for completions
  def fetch_auto_resp(comp_type, sub_cmd)
    case comp_type
    when :command
      list_commands
    when :account
      Awskeyring.list_account_names
    when :role
      Awskeyring.list_role_names
    when :path_type
      Awskeyring.list_console_path
    when :token
      Awskeyring.list_token_names
    when :browser_type
      Awskeyring.list_browsers
    else
      list_arguments(command: sub_cmd)
    end
  end

  # list command names
  def list_commands
    commands = self.class.all_commands.keys.map { |elem| elem.tr('_', '-') }
    commands.reject! { |elem| %w[autocomplete default].include?(elem) }
  end

  # list flags for a command
  def list_arguments(command:)
    options = self.class.all_commands[command].options.values
    exit 1 if options.empty?

    options.map(&:aliases).flatten! +
      options.map(&:switch_name)
  end

  # add warning about old keys
  def age_check_and_get(account:, no_token:)
    cred = Awskeyring.get_valid_creds(account: account, no_token: no_token)

    maxage = Awskeyring.key_age
    age = (Time.new - cred[:updated]).div Awskeyring::Awsapi::ONE_DAY
    warn I18n.t('message.age_check', account: account, age: age) unless age < maxage

    cred
  end

  # print exports from map
  def put_env_string(cred)
    env_var = Awskeyring::Awsapi.get_env_array(cred)
    env_var.each { |var, value| puts "export #{var}=\"#{value}\"" }
    Awskeyring::Awsapi::AWS_ENV_VARS.each { |key| puts "unset #{key}" unless env_var.key?(key) }
  end

  # select duration for sts token types
  def default_duration(duration, role, code)
    duration ||= Awskeyring::Awsapi::ONE_HOUR.to_s if role
    duration ||= Awskeyring::Awsapi::TWELVE_HOUR.to_s if code
    duration || Awskeyring::Awsapi::ONE_HOUR.to_s
  end

  # ask and validate input values.
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

  # ask for somthinng if its missing.
  def ask_missing(existing:, message:, secure: false, optional: false, limited_to: nil)
    existing || ask(message: message, secure: secure, optional: optional, limited_to: limited_to).strip
  end

  # ask in different ways
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

  # undo Bundler env vars
  def unbundle
    to_delete = ENV.keys.select { |elem| elem.start_with?('BUNDLER_ORIG_') }
    bundled_env = to_delete.map { |elem| elem[('BUNDLER_ORIG_'.length)..] }
    to_delete << 'BUNDLE_GEMFILE'
    bundled_env.each do |env_name|
      ENV[env_name] = ENV.fetch("BUNDLER_ORIG_#{env_name}", nil)
      to_delete << env_name if ENV["BUNDLER_ORIG_#{env_name}"].start_with? 'BUNDLER_'
    end
    to_delete.each do |env_name|
      ENV.delete(env_name)
    end
  end
end
