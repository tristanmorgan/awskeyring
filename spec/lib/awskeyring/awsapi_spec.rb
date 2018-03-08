require 'spec_helper'
require_relative '../../../lib/awskeyring/awsapi'

describe Awskeyring::Awsapi do
  context 'STS token is created' do
    let(:mfa_token) { 'AQoEXAMPLEH4aoAH0gNCAPget_session_token5TthT+FvwqnKwRcOIfrRh3c/LTo6UDdyJwOOvEVP' }
    let(:role_token) { 'AQoDYXdzEPT//////////wEXAMPLEtc764assume_roleDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMi' }
    let(:rofa_token) { 'AQoDYXdzEPT//////////wEXAMPLEtc764assume_roleDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMi' }
    before do
      ENV['AWS_DEFAULT_REGION'] = 'us-east-1'
      allow_any_instance_of(Aws::STS::Client).to receive(:assume_role).and_return({})
      allow_any_instance_of(Aws::STS::Client).to receive(:assume_role).with(
        duration_seconds: 3600,
        role_arn: 'blah',
        role_session_name: 'rspec-user'
      ).and_return(
        double(
          assumed_role_user: {
            arn: 'arn:aws:sts::123456789012:assumed-role/demo/Bob',
            assumed_role_id: 'ARO123EXAMPLE123:Bob'
          },
          credentials: {
            access_key_id: 'ASIAIOSFODNN7EXAMPLE',
            expiration: Time.parse('2011-07-15T23:28:33.359Z'),
            secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
            session_token: role_token
          },
          packed_policy_size: 6
        )
      )
      allow_any_instance_of(Aws::STS::Client).to receive(:assume_role).with(
        duration_seconds: 3600,
        role_arn: 'blah',
        role_session_name: 'rspec-user',
        serial_number: 'arn:mfa',
        token_code: '654321'
      ).and_return(
        double(
          assumed_role_user: {
            arn: 'arn:aws:sts::123456789012:assumed-role/demo/Bob',
            assumed_role_id: 'ARO123EXAMPLE123:Bob'
          },
          credentials: {
            access_key_id: 'ASIAIOSFODNN7EXAMPLE',
            expiration: Time.parse('2011-07-15T23:28:33.359Z'),
            secret_access_key: 'wJalrXUtnFEMI/MFADENG/bPxRfiCYzEXAMPLEKEY',
            session_token: rofa_token
          },
          packed_policy_size: 6
        )
      )
      allow_any_instance_of(Aws::STS::Client).to receive(:get_session_token).and_return(
        double(
          credentials: {
            access_key_id: 'ASIAIOSFODNN7EXAMPLE',
            expiration: Time.parse('2011-07-11T19:55:29.611Z'),
            secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
            session_token: mfa_token
          }
        )
      )
    end

    it 'assume a role no mfa' do
      expect(subject.get_token(
               key: 'blah', secret: 'blah',
               role_arn: 'blah',
               code: nil, mfa: nil,
               duration: 3600,
               user: 'rspec-user'
      )).to eq(
        key: 'ASIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
        token: role_token,
        expiry: Time.parse('2011-07-15T23:28:33.359Z')
      )
    end

    it 'assume a role with mfa' do
      expect(subject.get_token(
               key: 'blah', secret: 'blah',
               role_arn: 'blah',
               code: '654321', mfa: 'arn:mfa',
               duration: 3600,
               user: 'rspec-user'
      )).to eq(
        key: 'ASIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/MFADENG/bPxRfiCYzEXAMPLEKEY',
        token: rofa_token,
        expiry: Time.parse('2011-07-15T23:28:33.359Z')
      )
    end

    it 'retrieves a session with mfa' do
      expect(subject.get_token(
               key: 'blah', secret: 'blah',
               role_arn: nil,
               code: '654321', mfa: 'arn:mfa',
               duration: 3600,
               user: 'rspec-user'
      )).to eq(
        key: 'ASIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
        token: mfa_token,
        expiry: Time.parse('2011-07-11T19:55:29.611Z')
      )
    end
  end

  context 'When we try to access AWS Console' do
    let(:item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end

    before do
      ENV['AWS_DEFAULT_REGION'] = 'us-east-1'
      allow_any_instance_of(Aws::STS::Client).to receive(:get_federation_token)
        .and_return(
          double(
            credentials: {
              access_key_id: 'ASIATESTETSTTETS',
              secret_access_key: 'verybiglonghexkey',
              session_token: 'evenlongerbiglonghexkey',
              expiration: 5
            }
          )
        )
      allow(Net::HTTP).to receive(:get).and_return('{"SigninToken":"*** the SigninToken string ***"}')
    end

    it 'return a login_url to the AWS Console' do
      expect_any_instance_of(Aws::STS::Client).to receive(:get_federation_token)
      expect(subject.get_login_url(
               key: 'blah', secret: 'secretblah',
               token: nil, path: 'test',
               user: 'rspec-user'
      )).to eq('https://signin.aws.amazon.com/federation?Action=login&SigninToken=%2A%2A%2A+the+SigninToken+string+%2A%2A%2A&Destination=https%3A%2F%2Fconsole.aws.amazon.com%2Ftest%2Fhome')
    end

    it 'return a login_url to the AWS Console using a token' do
      expect_any_instance_of(Aws::STS::Client).to_not receive(:get_federation_token)
      expect(subject.get_login_url(
               key: 'blah', secret: 'secretblah',
               token: 'doubleblah', path: nil,
               user: 'rspec-user'
      )).to eq('https://signin.aws.amazon.com/federation?Action=login&SigninToken=%2A%2A%2A+the+SigninToken+string+%2A%2A%2A&Destination=https%3A%2F%2Fconsole.aws.amazon.com%2F%2Fhome')
    end
  end

  context 'roate a key' do
    let(:account) { 'test' }
    let(:key) { 'AKIA1234567890ABCDEF' }
    let(:secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:new_key) { 'AKIAIOSFODNN7EXAMPLE' }
    let(:new_secret) { 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY' }

    before do
      ENV['AWS_DEFAULT_REGION'] = 'us-east-1'
      allow_any_instance_of(Aws::IAM::Client).to receive(:list_access_keys).and_return(
        access_key_metadata: [
          {
            access_key_id: 'AKIATESTTEST',
            create_date: Time.parse('2016-12-01T22:19:58Z'),
            status: 'Active',
            user_name: 'Alice'
          }
        ]
      )
      allow_any_instance_of(Aws::IAM::Client).to receive(:create_access_key).and_return(
        access_key: {
          access_key_id: new_key,
          create_date: Time.parse('2015-03-09T18:39:23.411Z'),
          secret_access_key: new_secret,
          status: 'Active',
          user_name: 'Bob'
        }
      )
      allow_any_instance_of(Aws::IAM::Client).to receive(:delete_access_key).and_return({})
    end

    it 'rotates a secret access key' do
      expect(subject.rotate(account: account, key: key, secret: secret)).to eq(
        account: account,
        key: new_key,
        secret: new_secret
      )
    end
  end

  context 'fail to roate a key' do
    let(:account) { 'test' }
    let(:key) { 'AKIA1234567890ABCDEF' }
    let(:secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }

    before do
      ENV['AWS_DEFAULT_REGION'] = 'us-east-1'
      allow_any_instance_of(Aws::IAM::Client).to receive(:list_access_keys).and_return(
        access_key_metadata: [
          {
            access_key_id: key,
            create_date: Time.parse('2016-12-01T22:19:58Z'),
            status: 'Active',
            user_name: 'Alice'
          },
          {
            access_key_id: 'AKIA222222222EXAMPLE',
            create_date: Time.parse('2016-12-01T22:20:01Z'),
            status: 'Active',
            user_name: 'Alice'
          }
        ]
      )
    end

    it 'calls the rotate method and fails' do
      expect_any_instance_of(Aws::IAM::Client).to_not receive(:create_access_key)
      expect_any_instance_of(Aws::IAM::Client).to_not receive(:delete_access_key)

      expect do
        subject.rotate(account: account, key: key, secret: secret)
      end.to raise_error(SystemExit).and output(/You have two access keys for account test/).to_stderr
    end
  end
end
