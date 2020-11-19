# frozen_string_literal: true

require 'aws-sdk-iam'
require 'cgi'
require 'json'

# Awskeyring Module,
# gives you an interface to access keychains and items.
module Awskeyring
  # AWS API methods for Awskeyring
  module Awsapi # rubocop:disable Metrics/ModuleLength
    # Admin policy as json
    ADMIN_POLICY = {
      Version: '2012-10-17',
      Statement: [{
        Action: '*',
        Resource: '*',
        Effect: 'Allow'
      }]
    }.to_json.freeze

    # AWS Signin url
    AWS_SIGNIN_URL = 'https://signin.aws.amazon.com/federation'

    # AWS Env vars
    AWS_ENV_VARS = %w[
      AWS_ACCOUNT_NAME
      AWS_ACCESS_KEY_ID
      AWS_ACCESS_KEY
      AWS_CREDENTIAL_EXPIRATION
      AWS_SECRET_ACCESS_KEY
      AWS_SECRET_KEY
      AWS_SECURITY_TOKEN
      AWS_SESSION_TOKEN
    ].freeze

    # Twelve hours in seconds
    TWELVE_HOUR = (60 * 60 * 12)
    # One hour in seconds
    ONE_HOUR = (60 * 60 * 1)
    # Days in seconds
    ONE_DAY = (24 * 60 * 60)

    # Retrieves a temporary session token from AWS
    #
    # @param [Hash] params including
    #    key The aws_access_key_id
    #    secret The aws_secret_access_key
    #    user The local username
    #    mfa The users MFA arn
    #    code The MFA code
    #    duration time in seconds until expiry
    #    role_arn ARN of the role to assume
    # @return [Hash] with the new credentials
    #    key The aws_access_key_id
    #    secret The aws_secret_access_key
    #    token The aws_session_token
    #    expiry expiry time
    def self.get_token(params = {}) # rubocop:disable  Metrics/AbcSize, Metrics/MethodLength
      ENV['AWS_DEFAULT_REGION'] = 'us-east-1' unless region
      sts = Aws::STS::Client.new(access_key_id: params[:key], secret_access_key: params[:secret])

      params[:mfa] = nil unless params[:code]
      begin
        response =
          if params[:role_arn]
            sts.assume_role(
              duration_seconds: params[:duration].to_i,
              role_arn: params[:role_arn],
              role_session_name: params[:user],
              serial_number: params[:mfa],
              token_code: params[:code]
            )
          elsif params[:code]
            sts.get_session_token(
              duration_seconds: params[:duration].to_i,
              serial_number: params[:mfa],
              token_code: params[:code]
            )
          else
            sts.get_federation_token(
              name: params[:user],
              policy: ADMIN_POLICY,
              duration_seconds: params[:duration]
            )
          end
      rescue Aws::STS::Errors::AccessDenied => e
        warn e.to_s
        exit 1
      end

      {
        key: response.credentials[:access_key_id],
        secret: response.credentials[:secret_access_key],
        token: response.credentials[:session_token],
        expiry: response.credentials[:expiration]
      }
    end

    # Genarates AWS CLI compatible JSON
    # see credential_process in AWS Docs
    #
    # @param [String] key The aws_access_key_id
    # @param [String] secret The aws_secret_access_key
    # @param [String] token The aws_session_token
    # @param [String] expiry expiry time
    # @return [String] credential_process json
    def self.get_cred_json(key:, secret:, token:, expiry:)
      JSON.pretty_generate(
        Version: 1,
        AccessKeyId: key,
        SecretAccessKey: secret,
        SessionToken: token,
        Expiration: expiry
      )
    end

    # Generates Environment Variables for the AWS CLI
    #
    # @param [Hash] params including
    #    [String] account The aws account name
    #    [String] key The aws_access_key_id
    #    [String] secret The aws_secret_access_key
    #    [String] token The aws_session_token
    # @return [Hash] env_var hash
    def self.get_env_array(params = {})
      env_var = {}
      env_var['AWS_DEFAULT_REGION'] = 'us-east-1' unless region

      params[:expiration] = Time.at(params[:expiry]).iso8601 unless params[:expiry].nil?

      params.each_key do |param_name|
        AWS_ENV_VARS.each do |var_name|
          if var_name.include?(param_name.to_s.upcase) && !params[param_name].nil?
            env_var[var_name] = params[param_name]
          end
        end
      end

      env_var
    end

    # Verify Credentials are active and valid
    #
    # @param [String] key The aws_access_key_id
    # @param [String] secret The aws_secret_access_key
    # @param [String] token The aws_session_token
    def self.verify_cred(key:, secret:, token:)
      begin
        ENV['AWS_DEFAULT_REGION'] = 'us-east-1' unless region
        sts = Aws::STS::Client.new(access_key_id: key, secret_access_key: secret, session_token: token)
        sts.get_caller_identity
      rescue Aws::Errors::ServiceError => e
        warn e.to_s
        exit 1
      end
      true
    end

    # Retrieve credentials from the AWS Credentials file
    #
    # @param [String] account the profile name wanted
    # @return [Hash] with the new credentials
    #    key The aws_access_key_id
    #    secret The aws_secret_access_key
    #    token The aws_session_token
    #    expiry expiry time
    def self.get_credentials_from_file(account:)
      creds = Aws::SharedCredentials.new(profile_name: account)
      {
        account: account,
        key: creds.credentials.access_key_id,
        secret: creds.credentials.secret_access_key,
        token: creds.credentials.session_token,
        expiry: Time.new + TWELVE_HOUR,
        role: nil
      }
    end

    # Retrieves an AWS Console login url
    #
    # @param [String] key The aws_access_key_id
    # @param [String] secret The aws_secret_access_key
    # @param [String] token The aws_session_token
    # @param [String] user The local username
    # @param [String] path within the Console to access
    # @return [String] login_url to access
    def self.get_login_url(key:, secret:, token:, path:, user:)
      console_url = "https://console.aws.amazon.com/#{path}/home"

      unless token
        cred = get_token({ key: key, secret: secret, user: user, duration: TWELVE_HOUR })
        key = cred[:key]
        secret = cred[:secret]
        token = cred[:token]
      end

      session_json = {
        sessionId: key,
        sessionKey: secret,
        sessionToken: token
      }.to_json

      destination_param = "&Destination=#{CGI.escape(console_url)}"

      "#{AWS_SIGNIN_URL}?Action=login#{token_param(session_json: session_json)}#{destination_param}"
    end

    # Get the signin token param
    private_class_method def self.token_param(session_json:)
      get_signin_token_url = AWS_SIGNIN_URL + '?Action=getSigninToken' \
                             '&Session=' + CGI.escape(session_json)

      uri       = URI(get_signin_token_url)
      request   = Net::HTTP.new(uri.host, uri.port)
      request.use_ssl = true
      returned_content = request.get(uri).body

      signin_token = JSON.parse(returned_content)['SigninToken']
      "&SigninToken=#{CGI.escape(signin_token)}"
    end

    # Get the current region
    #
    # @return [String] current configured region
    def self.region
      keys = %w[AWS_REGION AMAZON_REGION AWS_DEFAULT_REGION]
      region = ENV.values_at(*keys).compact.first
      region || Aws.shared_config.region(profile: 'default')
    end

    # Rotates the AWS access keys
    #
    # @param [String] key The aws_access_key_id
    # @param [String] secret The aws_secret_access_key
    # @param [String] account the associated account name.
    # @return [String] key The aws_access_key_id
    # @return [String] secret The aws_secret_access_key
    # @return [String] account the associated account name.
    def self.rotate(account:, key:, secret:, key_message:) # rubocop:disable  Metrics/MethodLength
      ENV['AWS_DEFAULT_REGION'] = 'us-east-1' unless region
      iam = Aws::IAM::Client.new(access_key_id: key, secret_access_key: secret)

      if iam.list_access_keys[:access_key_metadata].length > 1
        warn key_message
        exit 1
      end

      new_key = iam.create_access_key[:access_key]
      iam = Aws::IAM::Client.new(
        access_key_id: new_key[:access_key_id],
        secret_access_key: new_key[:secret_access_key]
      )
      retry_backoff do
        iam.delete_access_key(
          access_key_id: key
        )
      end
      {
        account: account,
        key: new_key[:access_key_id],
        secret: new_key[:secret_access_key]
      }
    end

    # Retry the call with backoff
    #
    # @param [Block] block the block to retry.
    def self.retry_backoff(&block)
      retries ||= 1
      begin
        yield block
      rescue Aws::IAM::Errors::InvalidClientTokenId => e
        if retries < 4
          sleep 2**retries
          retries += 1
          retry
        end
        warn e.message
        exit 1
      end
    end
  end
end
