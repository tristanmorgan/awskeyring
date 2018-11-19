require 'spec_helper'
require 'thor'
require_relative '../../lib/awskeyring_command'

describe AwskeyringCommand do
  context 'When we try to access AWS with a token' do
    before do
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false).and_return(
        account: 'test',
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token',
        updated: Time.parse('2011-08-01T22:20:01Z')
      )
      allow(Awskeyring::Awsapi).to receive(:get_login_url).and_return('login-url')
      allow(Process).to receive(:spawn).exactly(1).with('open "login-url"').and_return(9999)
      allow(Process).to receive(:wait).exactly(1).with(9999)
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
    end

    it 'opens the AWS Console' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)
      expect(Awskeyring::Awsapi).to receive(:get_login_url).with(
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token',
        path: 'console',
        user: ENV['USER']
      )
      expect(Process).to receive(:spawn).exactly(1).with('open "login-url"')
      AwskeyringCommand.start(%w[console test])
    end

    it 'prints the AWS Console URL' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)
      expect(Awskeyring::Awsapi).to receive(:get_login_url).with(
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token',
        path: 'console',
        user: ENV['USER']
      )
      expect(Process).to_not receive(:spawn).with('open "login-url"')
      expect do
        AwskeyringCommand.start(%w[console test --no-open])
      end.to output(/login-url/).to_stdout
    end
  end

  context 'When we try to access AWS without a token' do
    before do
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false).and_return(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil,
        updated: Time.parse('2011-08-01T22:20:01Z')
      )
      allow(Awskeyring::Awsapi).to receive(:get_login_url).and_return('login-url')
      allow(Process).to receive(:spawn).exactly(1).with('open "login-url"').and_return(9999)
      allow(Process).to receive(:wait).exactly(1).with(9999)
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
    end

    it 'opens the AWS Console' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)
      expect(Awskeyring::Awsapi).to receive(:get_login_url).with(
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil,
        path: 'test',
        user: ENV['USER']
      )
      expect(Process).to receive(:spawn).with('open "login-url"')
      AwskeyringCommand.start(%w[console test -p test])
    end
  end

  context 'When we try to retrieve a token' do
    before do
      allow(Awskeyring).to receive(:delete_token).with(account: 'test', message: '# Removing STS credentials')
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true).and_return(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        updated: Time.parse('2011-08-01T22:20:01Z')
      )
      allow(Awskeyring).to receive(:get_role_arn).with(role_name: 'role').and_return(
        'arn:aws:iam::012345678901:role/test'
      )

      allow(Awskeyring).to receive(:add_token)
      allow(Awskeyring::Awsapi).to receive(:get_token)
        .and_return(
          key: 'ASIAEXAMPLE',
          secret: 'bigishLongSecret',
          token: 'VeryveryVeryLongSecret',
          expiry: '1422992424',
          updated: Time.parse('2011-08-01T22:20:01Z')
        )
      allow(Thor::LineEditor).to receive(:readline).and_return('invalid')
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
    end

    it 'tries to receive a new token' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true)
      expect(Awskeyring).to receive(:get_role_arn).with(role_name: 'role')
      expect(Awskeyring).to receive(:add_token).with(
        account: 'test',
        key: 'ASIAEXAMPLE',
        secret: 'bigishLongSecret',
        token: 'VeryveryVeryLongSecret',
        expiry: '1422992424',
        role: 'role'
      )
      expect(Awskeyring::Awsapi).to receive(:get_token).with(
        code: nil,
        role_arn: 'arn:aws:iam::012345678901:role/test',
        duration: '3600',
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        user: ENV['USER']
      )

      expect do
        AwskeyringCommand.start(%w[token test -r role])
      end.to output(
        "# Token saved for account test\n# Authentication valid until #{Time.at(1_422_992_424)}\n"
      ).to_stdout
    end

    it 'tries to receive a new token with an MFA' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true)
      expect(Awskeyring).to receive(:add_token).with(
        account: 'test',
        key: 'ASIAEXAMPLE',
        secret: 'bigishLongSecret',
        token: 'VeryveryVeryLongSecret',
        expiry: '1422992424',
        role: nil
      )
      expect(Awskeyring::Awsapi).to receive(:get_token).with(
        code: '987654',
        role_arn: nil,
        duration: '43200',
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        user: ENV['USER']
      )

      expect do
        AwskeyringCommand.start(%w[token test -c 987654])
      end.to output(
        "# Token saved for account test\n# Authentication valid until #{Time.at(1_422_992_424)}\n"
      ).to_stdout
    end

    it 'tries to receive a new token with an MFA and role' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true)
      expect(Awskeyring).to receive(:add_token).with(
        account: 'test',
        key: 'ASIAEXAMPLE',
        secret: 'bigishLongSecret',
        token: 'VeryveryVeryLongSecret',
        expiry: '1422992424',
        role: 'role'
      )
      expect(Awskeyring::Awsapi).to receive(:get_token).with(
        code: '987654',
        role_arn: 'arn:aws:iam::012345678901:role/test',
        duration: '3600',
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        user: ENV['USER']
      )

      expect do
        AwskeyringCommand.start(%w[token test -r role -c 987654])
      end.to output(
        "# Token saved for account test\n# Authentication valid until #{Time.at(1_422_992_424)}\n"
      ).to_stdout
    end

    it 'tries to receive a new token without an mfa or role' do
      expect(Awskeyring::Awsapi).to receive(:get_token).with(
        code: nil,
        role_arn: nil,
        duration: '3600',
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        user: ENV['USER']
      )

      expect do
        AwskeyringCommand.start(%w[token test])
      end.to output(
        "# Token saved for account test\n# Authentication valid until #{Time.at(1_422_992_424)}\n"
      ).to_stdout
    end

    it 'tries to receive a new token with an invalid MFA' do
      expect do
        AwskeyringCommand.start(%w[token test -c invalid])
      end.to raise_error(SystemExit).and output(/Invalid MFA CODE/).to_stderr
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
      allow(Awskeyring).to receive(:add_account).and_return(nil)
      allow(Awskeyring).to receive(:update_account).and_return(nil)
      allow(Thor::LineEditor).to receive(:readline).and_return('')
      allow(Awskeyring::Awsapi).to receive(:verify_cred)
        .and_return(true)
    end

    it 'tries to add a valid account' do
      expect(Awskeyring::Awsapi).to receive(:verify_cred)
      expect(Awskeyring).to_not receive(:update_account)
      expect(Awskeyring).to receive(:add_account)
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key])
      end.to output("# Added account test\n").to_stdout
    end

    it 'tries to update a valid account' do
      expect(Awskeyring::Awsapi).to receive(:verify_cred)
      expect(Awskeyring).to receive(:update_account)
      expect(Awskeyring).to_not receive(:add_account)
      expect do
        AwskeyringCommand.start(['update', 'test', '-k', access_key, '-s', secret_access_key])
      end.to output("# Updated account test\n").to_stdout
    end

    it 'tries to add a valid account without remote tests' do
      expect(Awskeyring::Awsapi).to_not receive(:verify_cred)
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key, '-r'])
      end.to output("# Added account test\n").to_stdout
    end

    it 'tries to add a valid account with ARN' do
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
  end

  context 'When we try to add an AWS account' do
    let(:access_key) { 'AKIA0123456789ABCDEF' }
    let(:secret_access_key) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:bad_mfa_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    before do
      allow(Awskeyring).to receive(:add_account).and_return(nil)
      allow(Thor::LineEditor).to receive(:readline).and_return(bad_mfa_arn)
    end

    it 'tries to add an invalid mfa' do
      expect do
        AwskeyringCommand.start(['add', 'test', '-k', access_key, '-s', secret_access_key, '-m', bad_mfa_arn])
      end.to raise_error(SystemExit).and output(/Invalid MFA ARN/).to_stderr
    end
  end

  context 'When we try to add a Role' do
    let(:role_arn) { 'arn:aws:iam::012345678901:role/readonly' }
    let(:bad_role_arn) { 'arn:azure:iamnot::ABCD45678901:Administrators' }

    before do
      allow(Awskeyring).to receive(:add_role).and_return(nil)
      allow(Thor::LineEditor).to receive(:readline).and_return('')
    end

    it 'tries to add a valid role' do
      expect do
        AwskeyringCommand.start(['add-role', 'readonly', '-a', role_arn])
      end.to output(/# Added role readonly/).to_stdout
    end

    it 'tries to add an invalid role arn' do
      expect do
        AwskeyringCommand.start(['add-role', 'readonly', '-a', bad_role_arn])
      end.to raise_error(SystemExit).and output(/Invalid Role ARN/).to_stderr
    end
  end

  context 'when we try to rotate keys' do
    before do
      allow(Awskeyring).to receive(:get_valid_creds).and_return(
        account: 'test',
        key: 'AKIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
        token: nil,
        updated: Time.parse('2016-12-01T22:20:01Z')
      )

      allow(Awskeyring).to receive(:update_account).and_return(true)
      allow(Awskeyring).to receive(:key_age).and_return(90)

      allow(Awskeyring::Awsapi).to receive(:rotate).with(
        account: 'test',
        key: 'AKIAIOSFODNN7EXAMPLE',
        key_message: '# You have two access keys for account test',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY'
      ).and_return(
        account: 'test',
        key: 'AKIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY'
      )
      allow(Time).to receive(:new).and_return(Time.parse('2017-03-11T19:55:29.611Z'))
    end

    it 'calls the rotate method' do
      expect(Awskeyring).to receive(:update_account).with(
        account: 'test',
        key: 'AKIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY'
      )

      expect do
        AwskeyringCommand.start(%w[rotate test])
      end.to output(/# Updated account test/).to_stdout
    end

    it 'warns about the age of the creds' do
      expect do
        AwskeyringCommand.start(%w[env test])
      end.to output(/# Creds for account test are 99 days old./).to_stderr
    end
  end

  context 'when we try to rotate too many keys' do
    let(:old_item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end

    before do
      allow(Awskeyring).to receive(:get_valid_creds).and_return(
        account: 'test',
        key: 'AKIAIOSFODNN7EXAMPLE',
        secret: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY',
        token: nil,
        updated: Time.parse('2016-12-01T22:20:01Z')
      )
      allow_any_instance_of(Aws::IAM::Client).to receive(:list_access_keys).and_return(
        access_key_metadata: [
          {
            access_key_id: 'AKIATESTTEST',
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
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true)
      expect(Awskeyring).to_not receive(:update_account)

      expect_any_instance_of(Aws::IAM::Client).to_not receive(:create_access_key)
      expect_any_instance_of(Aws::IAM::Client).to_not receive(:delete_access_key)

      expect do
        AwskeyringCommand.start(%w[rotate test])
      end.to raise_error(SystemExit).and output(/# You have two access keys for account test/).to_stderr
    end
  end
end
