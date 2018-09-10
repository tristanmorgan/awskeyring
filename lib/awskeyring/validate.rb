# Awskeyring Module,
# gives you an interface to access keychains and items.
module Awskeyring
  # Validation methods for Awskeyring
  module Validate
    # Validate an account name
    #
    # @param [String] account_name the associated account name.
    def self.account_name(account_name)
      raise 'Invalid Account Name' unless account_name =~ /\S+/

      account_name
    end

    # Validate an AWS Access Key ID
    #
    # @param [String] aws_access_key The aws_access_key_id
    def self.access_key(aws_access_key)
      raise 'Invalid Access Key' unless aws_access_key =~ /\AAKIA[A-Z0-9]{12,16}\z/

      aws_access_key
    end

    # Validate an AWS Secret Key ID
    #
    # @param [String] aws_secret_access_key The aws_secret_access_key
    def self.secret_access_key(aws_secret_access_key)
      raise 'Secret Access Key is not 40 chars' if aws_secret_access_key.length != 40

      aws_secret_access_key
    end

    # Validate an Users mfa ARN
    #
    # @param [String] mfa_arn The users MFA arn
    def self.mfa_arn(mfa_arn)
      raise 'Invalid MFA ARN' unless mfa_arn =~ %r(\Aarn:aws:iam::[0-9]{12}:mfa\/\S*\z)

      mfa_arn
    end

    # Validate a Role name
    #
    # @param [String] role_name
    def self.role_name(role_name)
      raise 'Invalid Role Name' unless role_name =~ /\S+/

      role_name
    end

    # Validate a Role ARN
    #
    # @param [String] role_arn The role arn
    def self.role_arn(role_arn)
      raise 'Invalid Role ARN' unless role_arn =~ %r(\Aarn:aws:iam::[0-9]{12}:role\/\S*\z)

      role_arn
    end

    # Validate an MFA CODE
    #
    # @param [String] mfa_code The mfa code
    def self.mfa_code(mfa_code)
      raise 'Invalid MFA CODE' unless mfa_code =~ /\A\d{6}\z/

      mfa_code
    end
  end
end
