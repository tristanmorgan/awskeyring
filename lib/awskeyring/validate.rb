# frozen_string_literal: true

require 'base64'

# Awskeyring Module,
# gives you an interface to access keychains and items.
module Awskeyring
  # Validation methods for Awskeyring
  module Validate
    # Validate an account name
    #
    # @param [String] account_name the associated account name.
    def self.account_name(account_name)
      raise 'Invalid Account Name' unless /\S+/.match?(account_name)

      account_name
    end

    # Validate an AWS Access Key ID
    #
    # @param [String] aws_access_key The aws_access_key_id
    def self.access_key(aws_access_key)
      raise 'Invalid Access Key' unless /\AAKIA[A-Z0-9]{12,16}\z/.match?(aws_access_key)

      aws_access_key
    end

    # Validate an AWS Secret Key ID
    #
    # @param [String] aws_secret_access_key The aws_secret_access_key
    def self.secret_access_key(aws_secret_access_key)
      begin
        raise 'Invalid Secret Access Key' unless Base64.strict_decode64(aws_secret_access_key).length == 30
      rescue ArgumentError
        raise 'Invalid Secret Access Key'
      end

      aws_secret_access_key
    end

    # Validate an Users mfa ARN
    #
    # @param [String] mfa_arn The users MFA arn
    def self.mfa_arn(mfa_arn)
      raise 'Invalid MFA ARN' unless %r(\Aarn:aws:iam::[0-9]{12}:mfa/\S*\z).match?(mfa_arn)

      mfa_arn
    end

    # Validate a Role name
    #
    # @param [String] role_name
    def self.role_name(role_name)
      raise 'Invalid Role Name' unless /\S+/.match?(role_name)

      role_name
    end

    # Validate a Role ARN
    #
    # @param [String] role_arn The role arn
    def self.role_arn(role_arn)
      raise 'Invalid Role ARN' unless %r(\Aarn:aws:iam::[0-9]{12}:role/\S*\z).match?(role_arn)

      role_arn
    end

    # Validate an MFA CODE
    #
    # @param [String] mfa_code The mfa code
    def self.mfa_code(mfa_code)
      raise 'Invalid MFA CODE' unless /\A\d{6}\z/.match?(mfa_code)

      mfa_code
    end
  end
end
