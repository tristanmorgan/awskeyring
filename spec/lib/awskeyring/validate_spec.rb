# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/awskeyring/validate'

describe Awskeyring::Validate do
  context 'When validating inputs' do
    let(:test_account) { 'test' }
    let(:test_broken_account) { '' }

    it 'validates an account name' do
      expect { subject.account_name(test_account) }.to_not raise_error
    end

    it 'invalidates an account name' do
      expect { subject.account_name(test_broken_account) }.to raise_error('Invalid Account Name')
    end

    let(:test_key) { 'AKIA1234567890ABCDEF' }
    let(:test_broken_key) { 'AKIA1234567890' }

    it 'validates an access key' do
      expect { subject.access_key(test_key) }.to_not raise_error
    end

    it 'invalidates an access key' do
      expect { subject.access_key(test_broken_key) }.to raise_error('Invalid Access Key')
    end

    let(:test_secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:test_broken_secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FE' }

    it 'validates an secret access key' do
      expect { subject.secret_access_key(test_secret) }.to_not raise_error
    end

    it 'invalidates an secret access key' do
      expect { subject.secret_access_key(test_broken_secret) }.to raise_error('Secret Access Key is not 40 chars')
    end

    let(:test_mfa_code) { '321654' }
    let(:test_broken_mfa_code) { 'mfa_code' }

    it 'validates an mfa code' do
      expect { subject.mfa_code(test_mfa_code) }.to_not raise_error
    end

    it 'invalidates an mfa code' do
      expect { subject.mfa_code(test_broken_mfa_code) }.to raise_error('Invalid MFA CODE')
    end
  end

  context 'When validating inputs ARNs' do
    let(:mfa_arn) { 'arn:aws:iam::012345678901:mfa/ec2-user' }
    let(:bad_mfa_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }
    let(:role_arn) { 'arn:aws:iam::012345678901:role/readonly' }
    let(:bad_role_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    it 'validates an MFA ARN' do
      expect { subject.mfa_arn(mfa_arn) }.to_not raise_error
    end

    it 'invalidates an MFA ARN' do
      expect { subject.mfa_arn(bad_mfa_arn) }.to raise_error('Invalid MFA ARN')
    end

    it 'validates an Role ARN' do
      expect { subject.role_arn(role_arn) }.to_not raise_error
    end

    it 'invalidates an Role ARN' do
      expect { subject.role_arn(bad_role_arn) }.to raise_error('Invalid Role ARN')
    end
  end
end
