# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/awskeyring/awsapi'

describe Awskeyring::Awsapi do
  subject(:awsapi) { described_class }

  context 'with STS tokens created' do
    let(:mfa_token) { 'AQoEXAMPLEH4aoAH0gNCAPget_session_token5TthT+FvwqnKwRcOIfrRh3c/LTo6UDdyJwOOvEVP' }
    let(:role_token) { 'AQoDYXdzEPT//////////wEXAMPLEtc764assume_roleDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMi' }
    let(:rofa_token) { 'AQoDYXdzEPT//////////wEXAMPLEtc764assume_roleDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMi' }
    let(:fed_token) { 'AQoEXAMPLEH4aoAH0gNCAPget_federated_token5TthT+FvwqnKwRcOIfrRh3c/LTo6UDdyJwOOvEVP' }

    let(:sts_client) { instance_double(Aws::STS::Client) }

    before do
      allow(described_class).to receive(:region).and_return(nil)
      allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
      allow(sts_client).to receive(:assume_role).and_return({})
      allow(sts_client).to receive(:get_federation_token).and_return({})
      allow(sts_client).to receive(:assume_role).with(
        duration_seconds: 3600,
        role_arn: 'blah',
        role_session_name: 'rspec-user',
        serial_number: nil,
        token_code: nil
      ).and_return(
        instance_double(
          'HashMap',
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
      allow(sts_client).to receive(:assume_role).with(
        duration_seconds: 3600,
        role_arn: 'blah',
        role_session_name: 'rspec-user',
        serial_number: 'arn:mfa',
        token_code: '654321'
      ).and_return(
        instance_double(
          'HashMap',
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
      allow(sts_client).to receive(:get_session_token).and_return(
        instance_double(
          'HashMap',
          credentials: {
            access_key_id: 'ASIAIOSFODNN7EXAMPLE',
            expiration: Time.parse('2011-07-11T19:55:29.611Z'),
            secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
            session_token: mfa_token
          }
        )
      )
      allow(sts_client).to receive(:get_federation_token).with(
        name: 'rspec-user',
        policy: Awskeyring::Awsapi::ADMIN_POLICY,
        duration_seconds: 3600
      ).and_return(
        instance_double(
          'HashMap',
          credentials: {
            access_key_id: 'ASIAIUGFODNN7EXAMPLE',
            expiration: Time.parse('2012-07-11T19:55:29.611Z'),
            secret_access_key: 'wJalrXUXvFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
            session_token: fed_token
          }
        )
      )
    end

    it 'assume a role no mfa' do
      expect(awsapi.get_token(
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
      expect(awsapi.get_token(
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
      expect(awsapi.get_token(
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

    it 'retrieves a federated token' do
      expect(awsapi.get_token(
               key: 'blah', secret: 'blah',
               role_arn: nil,
               code: nil, mfa: nil,
               duration: 3600,
               user: 'rspec-user'
             )).to eq(
               key: 'ASIAIUGFODNN7EXAMPLE',
               secret: 'wJalrXUXvFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
               token: fed_token,
               expiry: Time.parse('2012-07-11T19:55:29.611Z')
             )
    end

    it 'returns a JSON formatted Credential' do
      expect(awsapi.get_cred_json(
               key: 'ASIAIOSFODNN7EXAMPLE',
               secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
               token: role_token,
               expiry: Time.parse('2011-07-11T19:55:29.611Z')
             )).to eq(%({
  "Version": 1,
  "AccessKeyId": "ASIAIOSFODNN7EXAMPLE",
  "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY",
  "SessionToken": "AQoDYXdzEPT//////////wEXAMPLEtc764assume_roleDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMi",
  "Expiration": "2011-07-11 19:55:29 UTC"
}))
    end
  end

  context 'when we try to access AWS Console' do
    let(:item) do
      instance_double(
        'HashMap',
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end
    let(:sts_client) { instance_double(Aws::STS::Client) }
    let(:net_http) { instance_double(Net::HTTP) }

    before do
      allow(described_class).to receive(:region).and_return(nil)
      allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
      allow(sts_client).to receive(:get_federation_token)
        .and_return(
          instance_double(
            'HashMap',
            credentials: {
              access_key_id: 'ASIATESTETSTTETS',
              secret_access_key: 'verybiglonghexkey',
              session_token: 'evenlongerbiglonghexkey',
              expiration: 5
            }
          )
        )
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:get)
        .and_return(
          instance_double(
            'HashMap',
            body: '{"SigninToken":"*** the SigninToken string ***"}'
          )
        )
      allow(net_http).to receive(:use_ssl=)
    end

    it 'return a login_url to the AWS Console' do
      expect(awsapi.get_login_url(
               key: 'blah', secret: 'secretblah',
               token: nil, path: 'test',
               user: 'rspec-user'
             )).to eq('https://signin.aws.amazon.com/federation?Action=login&SigninToken=%2A%2A%2A+the+SigninToken+string+%2A%2A%2A&Destination=https%3A%2F%2Fconsole.aws.amazon.com%2Ftest%2Fhome')
      expect(sts_client).to have_received(:get_federation_token)
    end

    it 'return a login_url to the AWS Console using a token' do
      expect(awsapi.get_login_url(
               key: 'blah', secret: 'secretblah',
               token: 'doubleblah', path: nil,
               user: 'rspec-user'
             )).to eq('https://signin.aws.amazon.com/federation?Action=login&SigninToken=%2A%2A%2A+the+SigninToken+string+%2A%2A%2A&Destination=https%3A%2F%2Fconsole.aws.amazon.com%2F%2Fhome')
      expect(sts_client).not_to have_received(:get_federation_token)
    end
  end

  context 'when credentials are verified' do
    let(:key) { 'AKIA1234567890ABCDEF' }
    let(:secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }

    let(:sts_client) { instance_double(Aws::STS::Client) }

    before do
      allow(described_class).to receive(:region).and_return(nil)
      allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
      allow(sts_client).to receive(:get_caller_identity).and_return(
        account: '123456789012',
        arn: 'arn:aws:iam::123456789012:user/Alice',
        user_id: 'AKIAI44QH8DHBEXAMPLE'
      )
    end

    it 'calls get_caller_identity' do
      expect(awsapi.verify_cred(key: key, secret: secret)).to be(true)
    end
  end

  context 'when keys are roated' do
    let(:account) { 'test' }
    let(:key) { 'AKIA1234567890ABCDEF' }
    let(:secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:new_key) { 'AKIAIOSFODNN7EXAMPLE' }
    let(:new_secret) { 'wJalrXUtnFEMI/K7MDENG/bPxRiCYzEXAMPLEKEY' }
    let(:key_message) { '# You have two access keys for account test' }

    let(:iam_client) { instance_double(Aws::IAM::Client) }

    before do
      allow(described_class).to receive(:region).and_return(nil)
      allow(Aws::IAM::Client).to receive(:new).and_return(iam_client)
      allow(iam_client).to receive(:list_access_keys).and_return(
        access_key_metadata: [
          {
            access_key_id: 'AKIATESTTEST',
            create_date: Time.parse('2016-12-01T22:19:58Z'),
            status: 'Active',
            user_name: 'Alice'
          }
        ]
      )
      allow(iam_client).to receive(:create_access_key).and_return(
        access_key: {
          access_key_id: new_key,
          create_date: Time.parse('2015-03-09T18:39:23.411Z'),
          secret_access_key: new_secret,
          status: 'Active',
          user_name: 'Bob'
        }
      )
      allow(iam_client).to receive(:delete_access_key).and_return({})
    end

    it 'rotates a secret access key' do
      expect(awsapi.rotate(account: account, key: key, secret: secret, key_message: key_message)).to eq(
        account: account,
        key: new_key,
        secret: new_secret
      )
    end
  end

  context 'when key rotation fails' do
    let(:account) { 'test' }
    let(:key) { 'AKIA1234567890ABCDEF' }
    let(:secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:key_message) { '# You have two access keys for account test' }
    let(:iam_client) { instance_double(Aws::IAM::Client) }

    before do
      allow(described_class).to receive(:region).and_return(nil)
      allow(Aws::IAM::Client).to receive(:new).and_return(iam_client)
      allow(iam_client).to receive(:list_access_keys).and_return(
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
      allow(iam_client).to receive(:create_access_key)
      allow(iam_client).to receive(:delete_access_key)
    end

    it 'calls the rotate method and fails' do
      expect do
        awsapi.rotate(account: account, key: key, secret: secret, key_message: key_message)
      end.to raise_error.and output(/# You have two access keys for account test/).to_stderr

      expect(iam_client).not_to have_received(:create_access_key)
      expect(iam_client).not_to have_received(:delete_access_key)
    end
  end

  context 'when there is no region set' do
    let(:role_token) { 'AQoDYXdzEPT//////////wEXAMPLEtc764assume_roleDOk4x4HIZ8j4FZTwdQWLWsKWHGBuFqwAeMi' }
    let(:sharedcfg) do
      instance_double(
        'HashMap',
        region: nil
      )
    end

    before do
      ENV['AWS_DEFAULT_REGION'] = nil
      ENV['AWS_REGION'] = nil
      ENV['AMAZON_REGION'] = nil
      allow(Aws).to receive(:shared_config).and_return(sharedcfg)
    end

    it 'retrieves the current region' do
      ENV['AWS_DEFAULT_REGION'] = 'us-west-1'
      expect(awsapi.region).to eq 'us-west-1'
    end

    it 'can not retrieve the current region' do
      expect(awsapi.region).to be nil
    end

    it 'returns an array of env vars for the Credential' do
      expect(awsapi.get_env_array(
               account: 'test',
               key: 'ASIAIOSFODNN7EXAMPLE',
               secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
               token: role_token
             )).to eq(
               'AWS_ACCESS_KEY' => 'ASIAIOSFODNN7EXAMPLE',
               'AWS_ACCESS_KEY_ID' => 'ASIAIOSFODNN7EXAMPLE',
               'AWS_ACCOUNT_NAME' => 'test',
               'AWS_DEFAULT_REGION' => 'us-east-1',
               'AWS_SECRET_ACCESS_KEY' => 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
               'AWS_SECRET_KEY' => 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
               'AWS_SECURITY_TOKEN' => role_token,
               'AWS_SESSION_TOKEN' => role_token
             )
    end
  end
end
