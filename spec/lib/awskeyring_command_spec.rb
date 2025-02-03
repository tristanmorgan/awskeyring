# frozen_string_literal: true

require 'spec_helper'
require 'thor'
require_relative '../../lib/awskeyring_command'

describe AwskeyringCommand do
  context 'when things are left to the defaults' do
    let(:current_version) { Awskeyring::VERSION }
    let(:latest_version) { '1.1.1' }
    let(:home_page) { Awskeyring::HOMEPAGE }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(false)
      allow(Thor::LineEditor).to receive(:readline).and_return('test')
      allow(Awskeyring).to receive(:init_keychain)
      allow(Awskeyring).to receive(:latest_version).and_return(latest_version)
    end

    it 'outputs help text' do
      expect { described_class.start(%w[help]) }
        .to output(/Awskeyring commands:/).to_stdout
    end

    it 'returns the version number' do
      expect(Awskeyring).not_to have_received(:latest_version)
      expect { described_class.start(%w[__version -r]) }
        .to output("Awskeyring v#{current_version}\nHomepage #{home_page}\n").to_stdout
    end

    it 'returns the version number with checks online' do
      expect { described_class.start(%w[--version]) }
        .to output(/latest version v1\.1\.1/).to_stdout
    end

    it 'prints autocomplete help text' do
      expect { described_class.start(%w[autocomplete one two]) }.to raise_error
        .and output(%r{enable autocomplete with 'complete -C /.+/\w+ \w+'}).to_stderr
    end

    it 'tells you that you must init the keychain' do
      expect { described_class.start(%w[list]) }.to raise_error
        .and output(/Config missing, run `\w+ initialise` to recreate./).to_stderr
    end

    it 'tells you it could not find the command test' do
      expect { described_class.start(%w[test]) }.to raise_error
        .and output(/Could not find command "test"./).to_stderr
    end

    it 'initialises the keychain' do
      expect { described_class.start(%w[initialise]) }
        .to output(/Add accounts to your test keychain with:/).to_stdout
    end

    it 'initialises the keychain by default' do
      expect { described_class.start([]) }
        .to output(/Add accounts to your test keychain with:/).to_stdout
    end
  end

  context 'when no accounts or roles are set' do
    before do
      allow(Awskeyring).to receive_messages(
        list_account_names: [],
        list_role_names: [],
        prefs: '{"awskeyring": "awskeyringtest"}'
      )
    end

    it 'outputs help text by default' do
      expect { described_class.start([]) }
        .to output(/^  \w+ --version, -v\s+# Prints the version/).to_stdout
    end

    it 'tells you that you must add accounts' do
      expect { described_class.start(%w[list]) }.to raise_error
        .and output(/No accounts added, run `\w+ add` to add./).to_stderr
    end

    it 'tells you that you must add roles' do
      expect { described_class.start(%w[list-role]) }.to raise_error
        .and output(/No roles added, run `\w+ add-role` to add./).to_stderr
    end
  end

  context 'when accounts and roles are set' do
    before do
      allow(Awskeyring).to receive_messages(
        list_account_names: %w[company personal sarviun],
        list_account_names_plus: %W[company\t123456 personal\t345678 sarviun\t432765],
        list_token_names: %w[personal sarsaml],
        list_role_names: %w[admin minion readonly],
        list_role_names_plus: %W[admin\tarn1 minion\tarn2 readonly\tarn3],
        list_console_path: %w[iam cloudformation vpc],
        list_browsers: %w[FireFox Safari],
        prefs: '{"awskeyring": "awskeyringtest"}'
      )
    end

    test_cases = [
      ['awskeyring con', %w[con awskeyring], "console\n", 'commands'],
      ['awskeyring list', %w[list awskeyring], "list\nlist-role\n", 'similar commands'],
      ['awskeyring help list',   %w[list help],  "list\nlist-role\n", 'commands for help'],
      ['awskeyring token sar',   %w[sar token],  "sarviun\n", 'account names'],
      ['awskeyring exec sar', %w[sar exec], "sarviun\n", 'accounts for exec'],
      ['awskeyring remove-role min', %w[min remove-role], "minion\n", 'roles'],
      ['awskeyring rmr min',  %w[min rmr], "minion\n", 'roles for short commands'],
      ['awskeyring rmt sar',  %w[sar rmt], "sarsaml\n", 'tokens'],
      ['awskeyring token sarviun minion 123456 --dura', %w[--dura 123456], "--duration\n", 'flags'],
      ['awskeyring token sarviun minion --dura', %w[--dura minion], "--duration\n", 'flags'],
      ['awskeyring con sarviun --p', %w[--p sarviun], "--path\n", 'flags'],
      ['awskeyring add sarveun --n', %w[--n sarveun], "--no-remote\n", 'flags for add'],
      ['awskeyring -v --n', %w[--n -v], "--no-remote\n", 'flags for --version'],
      ['awskeyring exec sarviun --no', %w[--no sarviun], "--no-bundle\n--no-token\n", 'flags for exec'],
      ['awskeyring exec sarviun base', %w[base sarviun], "base64\nbasename\n", 'flags for exec'],
      ['awskeyring console sarviun --path cloud', %w[cloud --path], "cloudformation\n", 'console paths'],
      ['awskeyring con sarviun --browser Sa',  %w[Sa --browser], "Safari\n", 'browsers']
    ]

    it 'list keychain items' do
      expect { described_class.start(%w[list]) }
        .to output("company\npersonal\nsarviun\n").to_stdout
    end

    it 'list keychain items with detail' do
      expect { described_class.start(%w[list -d]) }
        .to output("company\t123456\npersonal\t345678\nsarviun\t432765\n").to_stdout
    end

    it 'list keychain roles' do
      expect { described_class.start(%w[list-role]) }
        .to output("admin\nminion\nreadonly\n").to_stdout
    end

    it 'list keychain roles with detail' do
      expect { described_class.start(%w[list-role -d]) }
        .to output("admin\tarn1\nminion\tarn2\nreadonly\tarn3\n").to_stdout
    end

    it 'decodes an account number from a key' do
      expect { described_class.start(%w[decode AKIA234567ABCDEFGHIJ]) }
        .to output("747118721026\n").to_stdout
    end

    test_cases.shuffle.each do |testcase|
      it "lists #{testcase[3]} with autocomplete" do
        ENV['COMP_LINE'] = testcase[0]
        ENV['COMP_POINT'] = ENV['COMP_LINE'].size.to_s
        expect { described_class.start(testcase[1].unshift('autocomplete')) }
          .to output(testcase[2]).to_stdout
        ENV['COMP_LINE'] = nil
      end
    end

    it 'lists all commands with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring '
      ENV['COMP_POINT'] = ENV['COMP_LINE'].size.to_s
      expect { described_class.start(['autocomplete', '', 'awskeyring']) }
        .to output(/--version\nadd\nadd-role\nconsole\nenv\nexec\nhelp/).to_stdout
      ENV['COMP_LINE'] = nil
    end

    it 'lists double dash flags with autocomplete' do
      ENV['COMP_LINE'] = 'awskeyring env test --'
      ENV['COMP_POINT'] = ENV['COMP_LINE'].size.to_s
      allow(ARGF).to receive(:argv).and_return(['awskeyring', '--', 'test'])
      expect { described_class.start(%w[autocomplete test]) }
        .to output(/--force\n--no-token\n--test\n--unset/).to_stdout
      ENV['COMP_LINE'] = nil
    end

    it 'doesnt try to re-initialises the keychain' do
      expect do
        described_class.start(%w[initialise])
      end.to raise_error(SystemExit)
        .and output(%r{# .+/\.awskeyring exists\. no need to initialise\.\n}).to_stdout
    end
  end

  context 'when there is an account and a role' do
    before do
      allow(Awskeyring::Awsapi).to receive(:region).and_return(nil)
      allow(Awskeyring).to receive(:delete_account)
      allow(Awskeyring).to receive(:delete_role)
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false).and_return(
        account: 'test',
        key: 'AKIA234567ABCDEFGHIJ',
        secret: 'biglongbase64',
        token: nil,
        updated: Time.parse('2011-08-11T22:20:01Z')
      )
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
      allow(Awskeyring).to receive_messages(
        account_exists: 'test',
        role_exists: 'test',
        list_account_names: ['test'],
        list_role_names: ['test']
      )
    end

    it 'removes an account' do
      described_class.start(%w[remove test])
      expect(Awskeyring).to have_received(:account_exists).with('test')
      expect(Awskeyring).to have_received(:delete_account)
        .with(account: 'test', message: '# Removing account test')
    end

    it 'removes a role' do
      described_class.start(%w[remove-role test])
      expect(Awskeyring).to have_received(:delete_role).with(role_name: 'test', message: '# Removing role test')
    end

    it 'export an AWS Access key' do
      expect { described_class.start(%w[env test --force]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCOUNT_ID="747118721026"
export AWS_ACCESS_KEY_ID="AKIA234567ABCDEFGHIJ"
export AWS_ACCESS_KEY="AKIA234567ABCDEFGHIJ"
export AWS_SECRET_ACCESS_KEY="biglongbase64"
export AWS_SECRET_KEY="biglongbase64"
unset AWS_CREDENTIAL_EXPIRATION
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
    end

    it 'unsets all AWS Access keys' do
      expect { described_class.start(%w[env --unset]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
unset AWS_ACCOUNT_NAME
unset AWS_ACCOUNT_ID
unset AWS_ACCESS_KEY_ID
unset AWS_ACCESS_KEY
unset AWS_CREDENTIAL_EXPIRATION
unset AWS_SECRET_ACCESS_KEY
unset AWS_SECRET_KEY
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
      expect(Awskeyring).not_to have_received(:get_valid_creds)
    end

    it 'export a fake AWS Access key' do
      expect { described_class.start(%w[env test --test]) }
        .to output(/export AWS_DEFAULT_REGION="us-east-1"/).to_stdout
      expect(Awskeyring).not_to have_received(:get_valid_creds)
    end
  end

  context 'when there is an account, a role and a session token' do
    let(:env_vars) do
      { 'AWS_DEFAULT_REGION' => 'us-east-1',
        'AWS_ACCOUNT_NAME' => 'test',
        'AWS_ACCOUNT_ID' => '747118721026',
        'AWS_ACCESS_KEY_ID' => 'ASIA234567ABCDEFGHIJ',
        'AWS_ACCESS_KEY' => 'ASIA234567ABCDEFGHIJ',
        'AWS_CREDENTIAL_EXPIRATION' => Time.at(1_310_414_129).iso8601,
        'AWS_SECRET_ACCESS_KEY' => 'bigerlongbase64',
        'AWS_SECRET_KEY' => 'bigerlongbase64',
        'AWS_SECURITY_TOKEN' => 'evenlongerbase64token',
        'AWS_SESSION_TOKEN' => 'evenlongerbase64token' }
    end
    let(:good_exit) { instance_double(Process::Status) }

    before do
      allow(Awskeyring::Awsapi).to receive(:region).and_return(nil)
      allow(Awskeyring).to receive(:delete_token)
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: false).and_return(
        account: 'test',
        key: 'ASIA234567ABCDEFGHIJ',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token',
        role: 'role',
        expiry: Time.parse('2011-07-11T19:55:29.611Z').to_i,
        updated: Time.parse('2011-06-01T22:20:01Z')
      )
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test', no_token: true).and_return(
        account: 'test',
        key: 'AKIA234567ABCDEFGHIJ',
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
      allow(Process).to receive(:last_status).exactly(1).and_return(good_exit)
      allow(good_exit).to receive(:exitstatus).and_return(0)
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
      allow(Awskeyring).to receive_messages(
        account_exists: 'test',
        token_exists: 'test',
        list_account_names: ['test'],
        list_token_names: ['test']
      )
    end

    it 'removes a token' do
      described_class.start(%w[remove-token test])
      expect(Awskeyring).to have_received(:token_exists).with('test')
      expect(Awskeyring).to have_received(:delete_token)
        .with(account: 'test', message: '# Removing token for account test')
    end

    it 'export an AWS Session Token' do
      expect { described_class.start(%w[env test]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCOUNT_ID="747118721026"
export AWS_ACCESS_KEY_ID="ASIA234567ABCDEFGHIJ"
export AWS_ACCESS_KEY="ASIA234567ABCDEFGHIJ"
export AWS_CREDENTIAL_EXPIRATION="#{Time.at(1_310_414_129).iso8601}"
export AWS_SECRET_ACCESS_KEY="bigerlongbase64"
export AWS_SECRET_KEY="bigerlongbase64"
export AWS_SECURITY_TOKEN="evenlongerbase64token"
export AWS_SESSION_TOKEN="evenlongerbase64token"
)).to_stdout
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
    end

    it 'export an AWS Keys' do
      expect { described_class.start(%w[env test --no-token]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCOUNT_ID="747118721026"
export AWS_ACCESS_KEY_ID="AKIA234567ABCDEFGHIJ"
export AWS_ACCESS_KEY="AKIA234567ABCDEFGHIJ"
export AWS_SECRET_ACCESS_KEY="biglongbase64"
export AWS_SECRET_KEY="biglongbase64"
unset AWS_CREDENTIAL_EXPIRATION
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: true)
    end

    it 'provides JSON for use with credential_process' do
      expect { described_class.start(%w[json test]) }
        .to output("#{JSON.pretty_generate(
          Version: 1,
          AccessKeyId: 'ASIA234567ABCDEFGHIJ',
          SecretAccessKey: 'bigerlongbase64',
          SessionToken: 'evenlongerbase64token',
          Expiration: Time.at(Time.parse('2011-07-11T19:55:29.611Z').to_i).iso8601
        )}\n").to_stdout
      expect(Awskeyring).to have_received(:account_exists).with('test')
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
    end

    it 'provides a test account via JSON' do
      expect { described_class.start(%w[json test --test]) }
        .to output(/  "Version": 1,/).to_stdout
      expect(Awskeyring).not_to have_received(:get_valid_creds).with(account: 'test', no_token: false)
    end

    it 'runs an external command' do
      ENV['BUNDLER_ORIG_TEST_ENV'] = 'BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL'
      ENV['TEST_ENV'] = 'CHANGED'
      described_class.start(%w[exec test test-exec with params])
      expect(Process).to have_received(:spawn).exactly(1).with(
        env_vars,
        'test-exec with params'
      )
      expect(Awskeyring).to have_received(:account_exists).with('test')
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
      expect(ENV.fetch('BUNDLER_ORIG_TEST_ENV', nil)).to eq('BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL')
      expect(ENV.fetch('TEST_ENV', nil)).to eq('CHANGED')
    end

    it 'runs an external command and clears bundle' do
      ENV['BUNDLER_ORIG_TEST_ENV'] = 'BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL'
      ENV['TEST_ENV'] = 'CHANGED'
      described_class.start(%w[exec test --no-bundle test-exec with params])
      expect(Process).to have_received(:spawn).exactly(1).with(
        env_vars,
        'test-exec with params'
      )
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
      expect(ENV.fetch('TEST_ENV', nil)).to be_nil
    end

    it 'warns about a missing external command' do
      expect do
        described_class.start(%w[exec test])
      end.to raise_error.and output(/COMMAND not provided/).to_stderr
      expect(Process).not_to have_received(:spawn)
    end
  end
end
