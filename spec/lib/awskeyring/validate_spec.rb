# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/awskeyring/validate'

describe Awskeyring::Validate do
  subject(:validate) { described_class }

  context 'when validating inputs' do
    let(:test_account) { 'test' }
    let(:test_broken_account) { '' }

    let(:test_broken_mfa_code) { 'mfa_code' }
    let(:test_mfa_code) { '321654' }
    let(:test_broken_secret) { 'hI7XqAiaR_XJxKgCqG0Wo79jm2+GcRYP' }
    let(:test_secret) { 'vbkEXAMPLEa3TlCP2Fvmcbdp83LSaeDHtx13xc+M' }
    let(:test_broken_key) { 'AKIA1234567890' }
    let(:test_key) { 'AKIA234567ABCDEFGHIJ' }

    it 'validates an account name' do
      expect { validate.account_name(test_account) }.not_to raise_error
    end

    it 'invalidates an account name' do
      expect { validate.account_name(test_broken_account) }.to raise_error('Invalid Account Name')
    end

    it 'validates an access key' do
      expect { validate.access_key(test_key) }.not_to raise_error
    end

    it 'invalidates an access key' do
      expect { validate.access_key(test_broken_key) }.to raise_error('Invalid Access Key')
    end

    it 'validates an secret access key' do
      expect { validate.secret_access_key(test_secret) }.not_to raise_error
    end

    it 'invalidates an secret access key' do
      expect { validate.secret_access_key(test_broken_secret) }.to raise_error('Invalid Secret Access Key')
    end

    it 'validates an mfa code' do
      expect { validate.mfa_code(test_mfa_code) }.not_to raise_error
    end

    it 'invalidates an mfa code' do
      expect { validate.mfa_code(test_broken_mfa_code) }.to raise_error('Invalid MFA CODE')
    end
  end

  context 'when validating inputs ARNs' do
    let(:mfa_arn) { 'arn:aws:iam::012345678901:mfa/ec2-user' }
    let(:bad_mfa_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }
    let(:role_arn) { 'arn:aws:iam::012345678901:role/readonly' }
    let(:bad_role_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    it 'validates an MFA ARN' do
      expect { validate.mfa_arn(mfa_arn) }.not_to raise_error
    end

    it 'invalidates an MFA ARN' do
      expect { validate.mfa_arn(bad_mfa_arn) }.to raise_error('Invalid MFA ARN')
    end

    it 'validates an Role ARN' do
      expect { validate.role_arn(role_arn) }.not_to raise_error
    end

    it 'invalidates an Role ARN' do
      expect { validate.role_arn(bad_role_arn) }.to raise_error('Invalid Role ARN')
    end
  end
end
