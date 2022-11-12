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
      allow(Awskeyring).to receive(:list_account_names).and_return([])
      allow(Awskeyring).to receive(:list_role_names).and_return([])
      allow(Awskeyring).to receive(:prefs).and_return('{"awskeyring": "awskeyringtest"}')
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
      allow(Awskeyring).to receive(:list_account_names).and_return(%w[company personal servian])
      allow(Awskeyring).to receive(:list_token_names).and_return(%w[personal sersaml])
      allow(Awskeyring).to receive(:list_role_names).and_return(%w[admin minion readonly])
      allow(Awskeyring).to receive(:list_role_names_plus)
        .and_return(%W[admin\tarn1 minion\tarn2 readonly\tarn3])
      allow(Awskeyring).to receive(:list_console_path).and_return(%w[iam cloudformation vpc])
      allow(Awskeyring).to receive(:list_browsers).and_return(%w[FireFox Safari])
      allow(Awskeyring).to receive(:prefs).and_return('{"awskeyring": "awskeyringtest"}')
    end

    test_cases = [
      ['awskeyring con', %w[con awskeyring], "console\n", 'commands'],
      ['awskeyring list', %w[list awskeyring], "list\nlist-role\n", 'similar commands'],
      ['awskeyring help list',   %w[list help],  "list\nlist-role\n", 'commands for help'],
      ['awskeyring token ser',   %w[ser token],  "servian\n", 'account names'],
      ['awskeyring exec ser', %w[ser exec], "servian\n", 'accounts for exec'],
      ['awskeyring remove-role min', %w[min remove-role], "minion\n", 'roles'],
      ['awskeyring rmr min',  %w[min rmr], "minion\n", 'roles for short commands'],
      ['awskeyring rmt ser',  %w[ser rmt], "sersaml\n", 'tokens'],
      ['awskeyring token servian minion 123456 --dura', %w[--dura 123456], "--duration\n", 'flags'],
      ['awskeyring token servian minion --dura', %w[--dura minion], "--duration\n", 'flags'],
      ['awskeyring con servian --p', %w[--p servian], "--path\n", 'flags'],
      ['awskeyring add sarveun --n', %w[--n sarveun], "--no-remote\n", 'flags for add'],
      ['awskeyring -v --n', %w[--n -v], "--no-remote\n", 'flags for --version'],
      ['awskeyring exec servian --no', %w[--no servian], "--no-bundle\n--no-token\n", 'flags for exec'],
      ['awskeyring console servian --path cloud', %w[cloud --path], "cloudformation\n", 'console paths'],
      ['awskeyring con servian --browser Sa',  %w[Sa --browser], "Safari\n", 'browsers']
    ]

    it 'list keychain items' do
      expect { described_class.start(%w[list]) }
        .to output("company\npersonal\nservian\n").to_stdout
    end

    it 'list keychain roles' do
      expect { described_class.start(%w[list-role]) }
        .to output("admin\nminion\nreadonly\n").to_stdout
    end

    it 'list keychain roles with detail' do
      expect { described_class.start(%w[list-role -d]) }
        .to output("admin\tarn1\nminion\tarn2\nreadonly\tarn3\n").to_stdout
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
        .to output(/--force\n--no-token\n--unset/).to_stdout
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
      ENV['AWS_DEFAULT_REGION'] = nil
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
      allow(Awskeyring).to receive(:account_exists).and_return('test')
      allow(Awskeyring).to receive(:role_exists).and_return('test')
      allow(Awskeyring).to receive(:list_account_names).and_return(['test'])
      allow(Awskeyring).to receive(:list_role_names).and_return(['test'])
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
export AWS_ACCESS_KEY_ID="AKIATESTTEST"
export AWS_ACCESS_KEY="AKIATESTTEST"
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
  end

  context 'when there is an account, a role and a session token' do
    let(:env_vars) do
      { 'AWS_DEFAULT_REGION' => 'us-east-1',
        'AWS_ACCOUNT_NAME' => 'test',
        'AWS_ACCESS_KEY_ID' => 'ASIATESTTEST',
        'AWS_ACCESS_KEY' => 'ASIATESTTEST',
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
      allow(Process).to receive(:last_status).exactly(1).and_return(good_exit)
      allow(good_exit).to receive(:exitstatus).and_return(0)
      allow(Time).to receive(:new).and_return(Time.parse('2011-07-11T19:55:29.611Z'))
      allow(Awskeyring).to receive(:account_exists).and_return('test')
      allow(Awskeyring).to receive(:token_exists).and_return('test')
      allow(Awskeyring).to receive(:list_account_names).and_return(['test'])
      allow(Awskeyring).to receive(:list_token_names).and_return(['test'])
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
export AWS_ACCESS_KEY_ID="ASIATESTTEST"
export AWS_ACCESS_KEY="ASIATESTTEST"
export AWS_SECRET_ACCESS_KEY="bigerlongbase64"
export AWS_SECRET_KEY="bigerlongbase64"
export AWS_SECURITY_TOKEN="evenlongerbase64token"
export AWS_SESSION_TOKEN="evenlongerbase64token"
export AWS_CREDENTIAL_EXPIRATION="#{Time.at(1_310_414_129).iso8601}"
)).to_stdout
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
    end

    it 'export an AWS Keys' do
      expect { described_class.start(%w[env test --no-token]) }
        .to output(%(export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_NAME="test"
export AWS_ACCESS_KEY_ID="AKIATESTTEST"
export AWS_ACCESS_KEY="AKIATESTTEST"
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
          AccessKeyId: 'ASIATESTTEST',
          SecretAccessKey: 'bigerlongbase64',
          SessionToken: 'evenlongerbase64token',
          Expiration: Time.at(Time.parse('2011-07-11T19:55:29.611Z').to_i).iso8601
        )}\n").to_stdout
      expect(Awskeyring).to have_received(:account_exists).with('test')
      expect(Awskeyring).to have_received(:get_valid_creds).with(account: 'test', no_token: false)
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
