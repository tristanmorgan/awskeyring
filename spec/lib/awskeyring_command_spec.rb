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
      allow(Thor::LineEditor).to receive(:readline).and_return('test')
      allow(Awskeyring).to receive(:init_keychain)
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
        .and output(%r{enable autocomplete with 'complete -C \/.+\/\w+ \w+'}).to_stderr
    end

    it 'tells you that you must init the keychain' do
      expect { AwskeyringCommand.start(%w[list]) }.to raise_error(SystemExit)
        .and output(/Config missing, run `\w+ initialise` to recreate./).to_stderr
    end

    it 'tells you it could not find the command test' do
      expect { AwskeyringCommand.start(%w[test]) }.to output(/Could not find command "test"./).to_stderr
    end

    it 'initialises the keychain' do
      expect { AwskeyringCommand.start(%w[initialise]) }
        .to output(/Add accounts to your test keychain with:/).to_stdout
    end
  end

  context 'When accounts and roles are set' do
    before do
      allow(Awskeyring).to receive(:list_account_names).and_return(%w[company personal vibrato])
      allow(Awskeyring).to receive(:list_role_names).and_return(%w[admin minion readonly])
      allow(Awskeyring).to receive(:list_console_path).and_return(%w[iam cloudformation vpc])
    end

    it 'list keychain items' do
      expect { AwskeyringCommand.start(%w[list]) }
        .to output("company\npersonal\nvibrato\n").to_stdout
    end

    it 'list keychain roles' do
      expect { AwskeyringCommand.start(%w[list-role]) }
        .to output("admin\nminion\nreadonly\n").to_stdout
    end

    it 'lists accounts with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring token vib'
      expect { AwskeyringCommand.start(%w[awskeyring vib token]) }
        .to output("vibrato\n").to_stdout
      ENV['COMP_LINE'] = nil
    end

    it 'lists roles with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring token vibrato min'
      expect { AwskeyringCommand.start(%w[awskeyring min vibrato]) }
        .to output("minion\n").to_stdout
      ENV['COMP_LINE'] = nil
    end

    it 'lists commands with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring '
      expect { AwskeyringCommand.start(['awskeyring', '', 'awskeyring']) }
        .to output(/--version\nadd\nadd-role\nconsole\nenv\nexec\nhelp/).to_stdout
      ENV['COMP_LINE'] = nil
    end

    it 'lists flags with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring token vibrato minion --dura'
      expect { AwskeyringCommand.start(%w[awskeyring --dura minion]) }
        .to output("--duration\n").to_stdout
      ENV['COMP_LINE'] = nil
    end

    it 'lists console paths with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring console vibrato --path cloud'
      expect { AwskeyringCommand.start(%w[awskeyring cloud --path]) }
        .to output("cloudformation\n").to_stdout
      ENV['COMP_LINE'] = nil
    end
  end

  context 'When there is an account and a role' do
    before do
      allow(Awskeyring).to receive(:delete_account)
      allow(Awskeyring).to receive(:delete_role)
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false).and_return(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil,
        updated: Time.parse('2011-08-11T22:20:01Z')
      )
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
      allow(Awskeyring::Awsapi).to receive(:region).and_return(nil)
    end

    it 'removes an account' do
      expect(Awskeyring).to receive(:delete_account).with(account: 'test', message: '# Removing account test')
      AwskeyringCommand.start(%w[remove test])
    end

    it 'removes a role' do
      expect(Awskeyring).to receive(:delete_role).with(role_name: 'test', message: '# Removing role test')
      AwskeyringCommand.start(%w[remove-role test])
    end

    it 'export an AWS Access key' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)

      expect { AwskeyringCommand.start(%w[env test]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCESS_KEY_ID="AKIATESTTEST"
export AWS_ACCESS_KEY="AKIATESTTEST"
export AWS_SECRET_ACCESS_KEY="biglongbase64"
export AWS_SECRET_KEY="biglongbase64"
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
    end
  end

  context 'When there is an account, a role and a session token' do
    let(:env_vars) do
      { 'AWS_DEFAULT_REGION' => 'us-east-1',
        'AWS_ACCOUNT_NAME' => 'test',
        'AWS_ACCESS_KEY_ID' => 'ASIATESTTEST',
        'AWS_ACCESS_KEY' => 'ASIATESTTEST',
        'AWS_SECRET_ACCESS_KEY' => 'bigerlongbase64',
        'AWS_SECRET_KEY' => 'bigerlongbase64',
        'AWS_SECURITY_TOKEN' => 'evenlongerbase64token',
        'AWS_SESSION_TOKEN' => 'evenlongerbase64token' }
    end
    before do
      allow(Awskeyring::Awsapi).to receive(:region).and_return(nil)
      allow(Awskeyring).to receive(:delete_token)
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false).and_return(
        account: 'test',
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token',
        role: 'role',
        expiry: Time.parse('2011-07-11T19:55:29.611Z').to_i,
        updated: Time.parse('2011-06-01T22:20:01Z')
      )
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true).and_return(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil,
        expiry: nil,
        updated: Time.parse('2011-08-01T22:20:01Z')
      )
      allow(Process).to receive(:spawn).exactly(1).with(
        env_vars,
        'test-exec with params'
      ).and_return(8888)
      allow(Process).to receive(:wait).exactly(1).with(8888)
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
    end

    it 'removes a token' do
      expect(Awskeyring).to receive(:delete_token).with(account: 'test', message: '# Removing token for account test')
      AwskeyringCommand.start(%w[remove-token test])
    end

    it 'export an AWS Session Token' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)
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

    it 'export an AWS Keys' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true)
      expect { AwskeyringCommand.start(%w[env test --no-token]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCESS_KEY_ID="AKIATESTTEST"
export AWS_ACCESS_KEY="AKIATESTTEST"
export AWS_SECRET_ACCESS_KEY="biglongbase64"
export AWS_SECRET_KEY="biglongbase64"
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
    end

    it 'provides JSON for use with credential_process' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)
      expect { AwskeyringCommand.start(%w[json test]) }
        .to output(JSON.pretty_generate(
          Version: 1,
          AccessKeyId: 'ASIATESTTEST',
          SecretAccessKey: 'bigerlongbase64',
          SessionToken: 'evenlongerbase64token',
          Expiration: Time.at(Time.parse('2011-07-11T19:55:29.611Z').to_i).iso8601
        ) + "\n").to_stdout
    end

    it 'runs an external command' do
      expect(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false)
      expect(Process).to receive(:spawn).exactly(1).with(
        env_vars,
        'test-exec with params'
      )
      AwskeyringCommand.start(%w[exec test test-exec with params])
    end
  end
end
