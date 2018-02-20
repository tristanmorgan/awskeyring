require 'spec_helper'
require 'thor'
require_relative '../../lib/awskeyring_command'

describe AwskeyringCommand do
  context 'When we try to access AWS with a token' do
    let(:session_key) do
      double(
        attributes: { label: 'session-key test', account: 'ASIATESTTEST' },
        password: 'bigerlongbase64'
      )
    end
    let(:session_token) do
      double(
        attributes: { label: 'session-token test', account: 0 },
        password: 'evenlongerbase64token'
      )
    end

    before do
      allow(Awskeyring).to receive(:delete_expired).with(session_key, session_token)
                                                   .and_return([session_key, session_token])
      allow(Process).to receive(:spawn).exactly(1).with(/open "https:/).and_return(9999)
      allow(Process).to receive(:wait).exactly(1).with(9999)
    end

    it 'opens the AWS Console' do
      expect(Awskeyring).to receive(:get_pair).with('test').and_return(
        [session_key, session_token]
      )

      expect(Awskeyring).to_not receive(:get_item)
      expect { AwskeyringCommand.start(%w[console test]) }
        .to output("# Using temporary session credentials\n").to_stdout
    end
  end

  context 'When we try to access AWS without a token' do
    let(:item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end

    before do
      allow(Awskeyring).to receive(:get_pair).with('test').and_return(nil, nil)
      allow(Awskeyring).to receive(:get_item).with('test').and_return(item)
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
      allow(Process).to receive(:spawn).exactly(1).with(/open "https:/).and_return(9999)
      allow(Process).to receive(:wait).exactly(1).with(9999)
    end

    it 'opens the AWS Console' do
      expect(Awskeyring).to receive(:get_item).with('test').and_return(item)
      expect(Process).to receive(:spawn).with(/open "https:.*console.aws.amazon.com%2Ftest%2Fhome"/)
      AwskeyringCommand.start(%w[console test -p test])
    end
  end

  context 'When we try to add an AWS account' do
    let(:access_key) { 'AKIA0123456789ABCDEF' }
    let(:secret_access_key) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:mfa_arn) { 'arn:aws:iam::012345678901:mfa/readonly' }
    let(:bad_access_key) { 'akIA01_678F' }
    let(:bad_secret_access_key) { 'Password123' }
    let(:bad_mfa_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    before do
      allow(Awskeyring).to receive(:add_item).and_return(nil)
    end

    it 'tries to add a valid account' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key, '-m', mfa_arn])
      end.to output("# Added account test\n").to_stdout
    end

    it 'tries to add an invalid access_key' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', bad_access_key, '-s', secret_access_key, '-m', mfa_arn])
      end.to raise_error(SystemExit).and output(/Invalid Access Key/).to_stderr
    end

    it 'tries to add an invalid secret' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', bad_secret_access_key, '-m', mfa_arn])
      end.to raise_error(SystemExit).and output(/Secret Access Key is not 40 chars/).to_stderr
    end

    it 'tries to add an invalid mfa' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key, '-m', bad_mfa_arn])
      end.to raise_error(SystemExit).and output(/Invalid ARN/).to_stderr
    end
  end
end
