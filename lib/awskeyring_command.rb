require 'aws-sdk-iam'
require 'cgi'
require 'highline'
require 'json'
require 'open-uri'
require 'thor'

require_relative 'awskeyring'
require 'awskeyring/version'

# AWS Key-ring command line interface.
class AwskeyringCommand < Thor # rubocop:disable Metrics/ClassLength
  map %w[--version -v] => :__version
  map ['ls'] => :list
  map ['lsr'] => :list_role
  map ['rm'] => :remove
  map ['rmr'] => :remove_role

  desc '--version, -v', 'Prints the version'
  def __version
    puts Awskeyring::VERSION
  end

  desc 'initialise', 'Initialises a new KEYCHAIN'
  method_option :keychain, type: :string, aliases: '-n', desc: 'Name of KEYCHAIN to initialise.'
  def initialise # rubocop:disable  Metrics/AbcSize
    unless Awskeyring.prefs.empty?
      puts "#{Awskeyring::PREFS_FILE} exists. no need to initialise."
      exit 1
    end

    keychain = ask_missing(existing: options[:keychain], message: "Name for new keychain (default: 'awskeyring')")
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
  def env(account = nil)
    account = ask_missing(existing: account, message: 'account name')
    cred, temp_cred = get_valid_item_pair(account: account)
    token = temp_cred.password unless temp_cred.nil?
    put_env_string(
      account: cred.attributes[:label],
      key: cred.attributes[:account],
      secret: cred.password,
      token: token
    )
  end

  desc 'exec ACCOUNT command...', 'Execute a COMMAND with the environment set for an ACCOUNT'
  def exec(account, *command)
    cred, temp_cred = get_valid_item_pair(account: account)
    token = temp_cred.password unless temp_cred.nil?
    env_vars = env_vars(
      account: cred.attributes[:label],
      key: cred.attributes[:account],
      secret: cred.password,
      token: token
    )
    pid = spawn(env_vars, command.join(' '))
    Process.wait pid
  end

  desc 'add ACCOUNT', 'Adds an ACCOUNT to the keyring'
  method_option :key, type: :string, aliases: '-k', desc: 'AWS account key id.'
  method_option :secret, type: :string, aliases: '-s', desc: 'AWS account secret.'
  method_option :mfa, type: :string, aliases: '-m', desc: 'AWS virtual mfa arn.'
  def add(account = nil)
    account = ask_missing(existing: account, message: 'account name')
    key = ask_missing(existing: options[:key], message: 'access key id')
    secret = ask_missing(existing: options[:secret], message: 'secret access key', secure: true)
    mfa = ask_missing(existing: options[:mfa], message: 'mfa arn', optional: true)

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
  def add_role(role = nil)
    role = ask_missing(existing: role, message: 'role name')
    arn = ask_missing(existing: options[:arn], message: 'role arn')
    account = ask_missing(existing: account, message: 'account', optional: true)

    Awskeyring.add_role(
      role: role,
      arn: arn,
      account: account
    )
  end

  desc 'remove ACCOUNT', 'Removes an ACCOUNT from the keyring'
  def remove(account = nil)
    account = ask_missing(existing: account, message: 'account name')
    cred, temp_cred = get_valid_item_pair(account: account)
    Awskeyring.delete_pair(cred, temp_cred, "# Removing account #{account}")
  end

  map 'remove-role' => :remove_role
  desc 'remove-role ROLE', 'Removes a ROLE from the keyring'
  def remove_role(role = nil)
    role = ask_missing(existing: role, message: 'role name')
    item_role = Awskeyring.get_role(role)
    Awskeyring.delete_pair(item_role, nil, "# Removing role #{role}")
  end

  desc 'token ACCOUNT [ROLE] [MFA]', 'Create an STS Token from a ROLE or an MFA code'
  method_option :role, type: :string, aliases: '-r', desc: 'The ROLE to assume.'
  method_option :code, type: :string, aliases: '-c', desc: 'Virtual mfa CODE.'
  method_option :duration, type: :string, aliases: '-d', desc: 'Session DURATION in seconds.'
  def token(account = nil, role = nil, code = nil) # rubocop:disable all
    account = ask_missing(existing: account, message: 'account name')
    role ||= options[:role]
    code ||= options[:code]
    duration = options[:duration]
    duration ||= (60 * 60 * 1).to_s if role
    duration ||= (60 * 60 * 12).to_s if code

    if !role && !code
      warn 'Please use either a role or a code'
      exit 2
    end

    session_key, session_token = Awskeyring.get_pair(account)
    Awskeyring.delete_pair(session_key, session_token, '# Removing STS credentials') if session_key

    item = Awskeyring.get_item(account)
    item_role = Awskeyring.get_role(role) if role

    sts = Aws::STS::Client.new(access_key_id: item.attributes[:account], secret_access_key: item.password)

    begin
      response =
        if code && role
          sts.assume_role(
            duration_seconds: duration.to_i,
            role_arn: item_role.attributes[:account],
            role_session_name: ENV['USER'],
            serial_number: item.attributes[:comment],
            token_code: code
          )
        elsif role
          sts.assume_role(
            duration_seconds: duration.to_i,
            role_arn: item_role.attributes[:account],
            role_session_name: ENV['USER']
          )
        elsif code
          sts.get_session_token(
            duration_seconds: duration.to_i,
            serial_number: item.attributes[:comment],
            token_code: code
          )
        end
    rescue Aws::STS::Errors::AccessDenied => e
      puts e.to_s
      exit 1
    end

    Awskeyring.add_pair(
      account: account,
      key: response.credentials[:access_key_id],
      secret: response.credentials[:secret_access_key],
      token: response.credentials[:session_token],
      expiry: response.credentials[:expiration].to_i.to_s,
      role: role
    )

    puts "Authentication valid until #{response.credentials[:expiration]}"
  end

  desc 'console ACCOUNT', 'Open the AWS Console for the ACCOUNT'
  def console(account = nil) # rubocop:disable all
    account = ask_missing(existing: account, message: 'account name')
    cred, temp_cred = get_valid_item_pair(account: account)
    token = temp_cred.password unless temp_cred.nil?

    console_url = 'https://console.aws.amazon.com/console/home'
    signin_url = 'https://signin.aws.amazon.com/federation'
    policy_json = {
      Version: '2012-10-17',
      Statement: [{
        Action: '*',
        Resource: '*',
        Effect: 'Allow'
      }]
    }.to_json

    if temp_cred
      session_json = {
        sessionId: cred.attributes[:account],
        sessionKey: cred.password,
        sessionToken: token
      }.to_json
    else
      sts = Aws::STS::Client.new(access_key_id: cred.attributes[:account],
                                 secret_access_key: cred.password)

      session = sts.get_federation_token(name: ENV['USER'],
                                         policy: policy_json,
                                         duration_seconds: (60 * 60 * 12))
      session_json = {
        sessionId: session.credentials[:access_key_id],
        sessionKey: session.credentials[:secret_access_key],
        sessionToken: session.credentials[:session_token]
      }.to_json

    end
    get_signin_token_url = signin_url + '?Action=getSigninToken' \
                           '&Session=' + CGI.escape(session_json)

    returned_content = open(get_signin_token_url).read

    signin_token = JSON.parse(returned_content)['SigninToken']
    signin_token_param = '&SigninToken=' + CGI.escape(signin_token)
    destination_param = '&Destination=' + CGI.escape(console_url)

    login_url = signin_url + '?Action=login' + signin_token_param + destination_param

    pid = spawn("open \"#{login_url}\"")
    Process.wait pid
  end

  # autocomplete
  desc 'awskeyring CURR PREV', 'Autocompletion for bourne shells', hide: true
  def awskeyring(curr, prev)
    comp_line = ENV['COMP_LINE']
    unless comp_line
      warn "enable autocomplete with 'complete -C /path-to-command/awskeyring awskeyring'"
      exit 1
    end
    comp_len = comp_line.split.length
    comp_len += 1 if curr == ''

    comp_len = 2 if prev == 'help'
    comp_len = 4 if prev == 'remove-role'
    print_auto_resp(curr, comp_len)
  end

  private

  def print_auto_resp(curr, len) # rubocop:disable  Metrics/AbcSize
    case len
    when 2
      puts list_commands.select { |elem| elem.start_with?(curr) }.join("\n")
    when 3
      puts Awskeyring.list_item_names.select { |elem| elem.start_with?(curr) }.join("\n")
    when 4
      puts Awskeyring.list_role_names.select { |elem| elem.start_with?(curr) }.join("\n")
    else
      exit 1
    end
  end

  def list_commands
    self.class.all_commands.keys.map { |elem| elem.tr('_', '-') }
  end

  def get_valid_item_pair(account:)
    session_key, session_token = Awskeyring.get_pair(account)
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

  def env_vars(account:, key:, secret:, token:)
    env_var = {}
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
