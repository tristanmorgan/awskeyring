# Validation methods
module Awskeyring
  def self.account_name(account_name)
    raise 'Invalid Account Name' unless account_name =~ /\S+/
    account_name
  end

  def self.access_key(aws_access_key)
    raise 'Invalid Access Key' unless aws_access_key =~ /\AAKIA[A-Z0-9]{12,16}\z/
    aws_access_key
  end

  def self.secret_access_key(aws_secret_access_key)
    raise 'Secret Access Key is not 40 chars' if aws_secret_access_key.length != 40
    aws_secret_access_key
  end

  def self.mfa_arn(mfa_arn)
    raise 'Invalid MFA ARN' unless mfa_arn =~ %r(\A\z|\Aarn:aws:iam::[0-9]{12}:mfa\/\S*\z)
    mfa_arn
  end

  def self.role_name(account_name)
    raise 'Invalid Role Name' unless account_name =~ /\S+/
    account_name
  end

  def self.role_arn(role_arn)
    raise 'Invalid Role ARN' unless role_arn =~ %r(\Aarn:aws:iam::[0-9]{12}:role\/\S*\z)
    role_arn
  end
end
