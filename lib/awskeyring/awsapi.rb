require 'aws-sdk-iam'
require 'cgi'
require 'json'

# Awskeyring Module,
# gives you an interface to access keychains and items.
module Awskeyring
  # AWS API methods for Awskeyring
  module Awsapi # rubocop:disable Metrics/ModuleLength
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
      sts = Aws::STS::Client.new(access_key_id: params[:key], secret_access_key: params[:secret])

      begin
        response =
          if params[:code] && params[:role_arn]
            sts.assume_role(
              duration_seconds: params[:duration].to_i,
              role_arn: params[:role_arn],
              role_session_name: params[:user],
              serial_number: params[:mfa],
              token_code: params[:code]
            )
          elsif params[:role_arn]
            sts.assume_role(
              duration_seconds: params[:duration].to_i,
              role_arn: params[:role_arn],
              role_session_name: params[:user]
            )
          elsif params[:code]
            sts.get_session_token(
              duration_seconds: params[:duration].to_i,
              serial_number: params[:mfa],
              token_code: params[:code]
            )
          end
      rescue Aws::STS::Errors::AccessDenied => e
        puts e.to_s
        exit 1
      end

      {
        key: response.credentials[:access_key_id],
        secret: response.credentials[:secret_access_key],
        token: response.credentials[:session_token],
        expiry: response.credentials[:expiration]
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
    def self.get_login_url(key:, secret:, token:, path:, user:) # rubocop:disable  Metrics/AbcSize, Metrics/MethodLength
      console_url = "https://console.aws.amazon.com/#{path}/home"
      signin_url = 'https://signin.aws.amazon.com/federation'
      policy_json = {
        Version: '2012-10-17',
        Statement: [{
          Action: '*',
          Resource: '*',
          Effect: 'Allow'
        }]
      }.to_json

      if token
        session_json = {
          sessionId: key,
          sessionKey: secret,
          sessionToken: token
        }.to_json
      else
        sts = Aws::STS::Client.new(access_key_id: key,
                                   secret_access_key: secret)

        session = sts.get_federation_token(name: user,
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

      returned_content = Net::HTTP.get(URI.parse(get_signin_token_url))

      signin_token = JSON.parse(returned_content)['SigninToken']
      signin_token_param = '&SigninToken=' + CGI.escape(signin_token)
      destination_param = '&Destination=' + CGI.escape(console_url)

      signin_url + '?Action=login' + signin_token_param + destination_param
    end

    # Rotates the AWS access keys
    #
    # @param [String] key The aws_access_key_id
    # @param [String] secret The aws_secret_access_key
    # @param [String] account the associated account name.
    # @return [String] key The aws_access_key_id
    # @return [String] secret The aws_secret_access_key
    # @return [String] account the associated account name.
    def self.rotate(account:, key:, secret:) # rubocop:disable  Metrics/MethodLength
      iam = Aws::IAM::Client.new(access_key_id: key, secret_access_key: secret)

      if iam.list_access_keys[:access_key_metadata].length > 1
        warn "You have two access keys for account #{account}"
        exit 1
      end

      new_key = iam.create_access_key
      iam = Aws::IAM::Client.new(
        access_key_id: new_key[:access_key][:access_key_id],
        secret_access_key: new_key[:access_key][:secret_access_key]
      )
      retry_backoff do
        iam.delete_access_key(
          access_key_id: key
        )
      end
      {
        account: account,
        key: new_key[:access_key][:access_key_id],
        secret: new_key[:access_key][:secret_access_key]
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
