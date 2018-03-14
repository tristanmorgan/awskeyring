require 'spec_helper'
require 'thor'
require_relative '../../lib/awskeyring_command'

describe AwskeyringCommand do
  context 'When things are left to the defaults' do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(false)
    end

    it 'outputs help text' do
      expect { AwskeyringCommand.start([]) }
        .to output(/^  \w+ --version, -v\s+# Prints the version/).to_stdout
      expect { AwskeyringCommand.start(%w[help]) }
        .to output(/Commands:/).to_stdout
    end

    it 'returns the version number' do
      expect { AwskeyringCommand.start(%w[__version]) }
        .to output(/\d\.\d\.\d/).to_stdout
    end

    it 'prints autocomplete help text' do
      expect { AwskeyringCommand.start(%w[awskeyring one two]) }.to raise_error(SystemExit)
        .and output(%r{enable autocomplete with 'complete -C \/path-to-command\/\w+ \w+'}).to_stderr
    end

    it 'tells you that you must init the keychain' do
      expect { AwskeyringCommand.start(%w[list]) }.to raise_error(SystemExit)
        .and output(/Config missing, run `\w+ initialise` to recreate./).to_stderr
    end

    it 'tells you it could not find the command test' do
      expect { AwskeyringCommand.start(%w[test]) }.to output(/Could not find command "test"./).to_stderr
    end
  end

  context 'When accounts and roles are set' do
    before do
      allow(Awskeyring).to receive(:list_account_names).and_return(%w[company personal vibrato])
      allow(Awskeyring).to receive(:list_role_names).and_return(%w[admin minion readonly])
    end

    it 'list keychain items' do
      expect { AwskeyringCommand.start(%w[list]) }
        .to output("company\npersonal\nvibrato\n").to_stdout
    end

    it 'list keychain roles' do
      expect { AwskeyringCommand.start(%w[list-role]) }
        .to output("admin\nminion\nreadonly\n").to_stdout
    end
  end

  context 'When there is an account and a role' do
    before do
      allow(Awskeyring).to receive(:delete_account)
      allow(Awskeyring).to receive(:delete_role)
    end

    it 'removes an account' do
      expect(Awskeyring).to receive(:delete_account).with(account: 'test', message: '# Removing account test')
      AwskeyringCommand.start(%w[remove test])
    end

    it 'removes a role' do
      expect(Awskeyring).to receive(:delete_role).with(role_name: 'test', message: '# Removing role test')
      AwskeyringCommand.start(%w[remove-role test])
    end
  end

  context 'When there is an account, a role and a session token' do
    before do
      allow(Awskeyring).to receive(:delete_token)
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test').and_return(
        account: 'test',
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token'
      )
    end

    it 'removes a token' do
      expect(Awskeyring).to receive(:delete_token).with(account: 'test', message: '# Removing token for account test')
      AwskeyringCommand.start(%w[remove-token test])
    end

    it 'export an AWS Session Token' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test')
      ENV['AWS_DEFAULT_REGION'] = nil
      expect { AwskeyringCommand.start(%w[env test]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCESS_KEY_ID="ASIATESTTEST"
export AWS_ACCESS_KEY="ASIATESTTEST"
export AWS_SECRET_ACCESS_KEY="bigerlongbase64"
export AWS_SECRET_KEY="bigerlongbase64"
export AWS_SECURITY_TOKEN="evenlongerbase64token"
export AWS_SESSION_TOKEN="evenlongerbase64token"
)).to_stdout
    end
  end

  context 'When there is just an account' do
    before do
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test').and_return(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil
      )
    end

    it 'export an AWS Access key' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test')

      ENV['AWS_DEFAULT_REGION'] = 'us-east-1'
      expect { AwskeyringCommand.start(%w[env test]) }
        .to output(%(export AWS_ACCOUNT_NAME="test"
export AWS_ACCESS_KEY_ID="AKIATESTTEST"
export AWS_ACCESS_KEY="AKIATESTTEST"
export AWS_SECRET_ACCESS_KEY="biglongbase64"
export AWS_SECRET_KEY="biglongbase64"
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
    end
  end
end
