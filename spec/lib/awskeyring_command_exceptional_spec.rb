# frozen_string_literal: true

require 'spec_helper'
require 'thor'
require_relative '../../lib/awskeyring_command'

describe AwskeyringCommand do
  context 'when everything raises an exception' do
    let(:iam_client) { instance_double(Aws::IAM::Client) }
    let(:sts_client) { instance_double(Aws::STS::Client) }
    let(:test_tty) { instance_double(IO) }

    before do
      allow(Awskeyring).to receive(:get_valid_creds).and_return(
        account: 'test',
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: nil,
        updated: Time.parse('2011-08-01T22:20:01Z')
      )
      allow(Process).to receive(:spawn) do
        raise Errno::ENOENT
      end
      allow(Process).to receive(:wait).exactly(1).with(9999)
      allow(Awskeyring).to receive(:account_exists).and_return('test')
      allow(Awskeyring).to receive(:list_account_names).and_return(['test'])
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))

      allow(Aws::IAM::Client).to receive(:new).and_return(iam_client)
      allow(iam_client).to receive(:list_access_keys) do
        raise(Aws::Errors::ServiceError.new(nil, 'The security token included in the request is invalid'))
      end
      allow(Aws::STS::Client).to receive(:new).and_return(sts_client)
      allow(sts_client).to receive(:get_federation_token) do
        raise(Aws::STS::Errors::AccessDenied.new(
                nil,
                'The security token included in the request is invalid'
              ))
      end
      allow(test_tty).to receive(:isatty).and_return(true)
      allow(test_tty).to receive(:write)
    end

    after do
      $stdout = STDOUT # rubocop:disable RSpec/ExpectOutput
    end

    it 'fails to run an external command' do
      expect do
        described_class.start(%w[exec test test-exec with params])
      end.to raise_error(SystemExit).and output(/No such file or directory/).to_stderr
    end

    it 'fails to rotate access keys' do
      expect do
        described_class.start(%w[rotate test])
      end.to raise_error(SystemExit).and output(/The security token included in the request is invalid/).to_stderr
    end

    it 'fails to fetch a new token' do
      expect do
        described_class.start(%w[token test])
      end.to raise_error(SystemExit).and output(/The security token included in the request is invalid/).to_stderr
    end

    it 'fails to open the console' do
      expect do
        described_class.start(%w[console test])
      end.to raise_error(SystemExit).and output(/The security token included in the request is invalid/).to_stderr
    end

    it 'blocks showing JSON creds on console' do
      $stdout = test_tty # rubocop:disable RSpec/ExpectOutput
      expect do
        described_class.start(%w[json test])
      end.to raise_error(SystemExit).and output(/Output suppressed to a tty, --force to override/).to_stderr
    end

    it 'blocks showing creds on console' do
      $stdout = test_tty # rubocop:disable RSpec/ExpectOutput
      expect do
        described_class.start(%w[env test])
      end.to raise_error(SystemExit).and output(/Output suppressed to a tty, --force to override/).to_stderr
    end

    it 'allows showing creds on console' do
      $stdout = test_tty # rubocop:disable RSpec/ExpectOutput
      expect { described_class.start(%w[env test --force]) }
        .to output(%(export AWS_ACCOUNT_NAME="test"
export AWS_ACCESS_KEY_ID="ASIATESTTEST"
export AWS_ACCESS_KEY="ASIATESTTEST"
export AWS_SECRET_ACCESS_KEY="bigerlongbase64"
export AWS_SECRET_KEY="bigerlongbase64"
unset AWS_CREDENTIAL_EXPIRATION
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
    end
  end
end
