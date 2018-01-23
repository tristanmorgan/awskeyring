require 'spec_helper'
require 'thor'
require_relative '../lib/awskeyring_command'

describe AwskeyringCommand do # rubocop:disable Metrics/BlockLength
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

  it 'list keychain items' do
    allow(Awskeyring).to receive(:list_item_names).and_return(%w[company personal vibrato])

    expect { AwskeyringCommand.start(%w[list]) }
      .to output("company\npersonal\nvibrato\n").to_stdout
  end

  it 'list keychain roles' do
    allow(Awskeyring).to receive(:list_role_names).and_return(%w[admin minion readonly])

    expect { AwskeyringCommand.start(%w[list-role]) }
      .to output("admin\nminion\nreadonly\n").to_stdout
  end

  it 'removes an account' do
    cred = double(
      attributes: { label: 'role test', account: 'AKIATESTTEST' },
      password: 'biglongbase64'
    )
    allow(Awskeyring).to receive(:get_pair).with('test').and_return(nil, nil)
    expect(Awskeyring).not_to receive(:delete_expired)
    allow(Awskeyring).to receive(:get_item).with('test').and_return(
      cred
    )
    expect(Awskeyring).to receive(:delete_pair).with(cred, nil, '# Removing account test')
    AwskeyringCommand.start(%w[remove test])
  end

  it 'removes a role' do
    cred = double(
      attributes: { label: 'account test', account: 'arn:aws:iam::012345678901:role/test' },
      password: ''
    )
    allow(Awskeyring).to receive(:get_role).with('test').and_return(
      cred
    )
    expect(Awskeyring).to receive(:delete_pair).with(cred, nil, '# Removing role test')
    AwskeyringCommand.start(%w[remove-role test])
  end

  it 'export an AWS Access key' do
    allow(Awskeyring).to receive(:get_pair).with('test').and_return(nil, nil)
    expect(Awskeyring).not_to receive(:delete_expired)
    allow(Awskeyring).to receive(:get_item).with('test').and_return(
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    )

    expect { AwskeyringCommand.start(%w[env test]) }
      .to output(%(export AWS_ACCOUNT_NAME="account test"
export AWS_ACCESS_KEY_ID="AKIATESTTEST"
export AWS_ACCESS_KEY="AKIATESTTEST"
export AWS_SECRET_ACCESS_KEY="biglongbase64"
export AWS_SECRET_KEY="biglongbase64"
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
)).to_stdout
  end

  it 'export an AWS Session Token' do
    session_key = double(
      attributes: { label: 'session-key test', account: 'ASIATESTTEST' },
      password: 'bigerlongbase64'
    )
    session_token = double(
      attributes: { label: 'session-token test', account: 0 },
      password: 'evenlongerbase64token'
    )

    expect(Awskeyring).to receive(:get_pair).with('test').and_return(
      [session_key, session_token]
    )
    allow(Awskeyring).to receive(:delete_expired).with(session_key, session_token)
                                                 .and_return([session_key, session_token])

    expect(Awskeyring).to_not receive(:get_item)

    expect { AwskeyringCommand.start(%w[env test]) }
      .to output(%(# Using temporary session credentials
export AWS_ACCOUNT_NAME="session-key test"
export AWS_ACCESS_KEY_ID="ASIATESTTEST"
export AWS_ACCESS_KEY="ASIATESTTEST"
export AWS_SECRET_ACCESS_KEY="bigerlongbase64"
export AWS_SECRET_KEY="bigerlongbase64"
export AWS_SECURITY_TOKEN="evenlongerbase64token"
export AWS_SESSION_TOKEN="evenlongerbase64token"
)).to_stdout
  end
end
