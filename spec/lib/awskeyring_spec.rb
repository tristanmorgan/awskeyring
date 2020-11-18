# frozen_string_literal: true

require 'spec_helper'

describe Awskeyring do
  subject(:awskeyring) { described_class }

  context 'when there is no config file' do
    let(:write_success) { 'great success' }
    let(:prefs_file) do
      instance_double(
        'HashMap',
        name: '.awskeyring',
        write: ''
      )
    end
    let(:test_keychain) do
      instance_double(
        'HashMap',
        lock_interval: 0,
        lock_on_sleep: false
      )
    end

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(false)
      allow(File).to receive(:new).and_call_original
      allow(File).to receive(:new)
        .and_return(prefs_file)
      allow(prefs_file).to receive(:write)
        .and_return(write_success)
      allow(Keychain).to receive(:create)
        .and_return(test_keychain)
      allow(test_keychain).to receive(:lock_interval=)
      allow(test_keychain).to receive(:lock_on_sleep=)
    end

    it 'has a version number' do
      expect(Awskeyring::VERSION).not_to be nil
    end

    it 'has a default preferences file' do
      expect(Awskeyring::PREFS_FILE).not_to be nil
    end

    it 'can not load preferences' do
      expect(awskeyring.prefs).to eq({})
    end

    it 'creates a new file' do
      expect(awskeyring.init_keychain(awskeyring: 'awskeyringtest')).to eq(write_success)
    end
  end

  context 'when there is a config file' do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read)
        .with(/\.awskeyring/)
        .and_return('{ "awskeyring": "test", "keyage": 90 }')
    end

    let(:default_console) { %w[cloudformation ec2/v2 iam rds route53 s3 sns sqs vpc] }
    let(:default_browsers) { %w[Brave FireFox Opera Safari Vivaldi] }

    it 'loads preferences from a file' do
      expect(awskeyring.prefs).to eq('awskeyring' => 'test', 'keyage' => 90)
    end

    it 'provides a default list of console paths' do
      expect(awskeyring.list_console_path).to eq(default_console)
    end

    it 'provides a default list of browsers' do
      expect(awskeyring.list_browsers).to eq(default_browsers)
    end
  end

  context 'when there is accounts and roles' do
    let(:item) do
      instance_double(
        'HashMap',
        attributes: {
          label: 'account test',
          account: 'AKIATESTTEST',
          updated_at: Time.parse('2016-12-01T22:20:01Z'),
          comment: 'arn:aws:iam::012345678901:mfa/ec2-user'
        },
        password: 'biglongbase64'
      )
    end
    let(:role) do
      instance_double(
        'HashMap',
        attributes: { label: 'role test', account: 'arn:aws:iam::012345678901:role/test' },
        password: ''
      )
    end
    let(:all_list) { [item, role] }
    let(:keychain) { instance_double('Keychain::Keychain', generic_passwords: all_list, lock_interval: 300) }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read)
        .with(/\.awskeyring/)
        .and_return('{ "awskeyring": "test", "keyage": 90 }')
      allow(all_list).to receive(:where).and_return([nil])
      allow(all_list).to receive(:where).with(label: 'account test').and_return([item])
      allow(all_list).to receive(:where).with(label: 'role test').and_return([role])
      allow(item).to receive(:delete)
      allow(role).to receive(:delete)
      allow(Keychain).to receive(:open).and_return(keychain)
    end

    it 'returns a hash with the creds' do
      expect(awskeyring.get_valid_creds(account: 'test', no_token: true)).to eq(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil,
        expiry: nil,
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        updated: Time.parse('2016-12-01T22:20:01Z')
      )
    end

    it 'tries to delete an account by name' do
      expect do
        awskeyring.delete_account(account: 'test', message: 'test delete message')
      end.to output(/test delete message/).to_stdout
      expect(item).to have_received(:delete)
    end

    it 'returns a hash with the role' do
      expect(awskeyring.get_role_arn(role_name: 'test')).to eq(
        'arn:aws:iam::012345678901:role/test'
      )
    end

    it 'tries to delete a role by name' do
      expect do
        awskeyring.delete_role(role_name: 'test', message: 'test delete message')
      end.to output(/test delete message/).to_stdout
      expect(role).to have_received(:delete)
    end
  end

  context 'when there is accounts and roles and tokens' do
    let(:access_key) { 'AKIA1234567890ABCDEF' }
    let(:role_arn) { 'arn:aws:iam::012345678901:role/test' }
    let(:item) do
      instance_double(
        'HashMap',
        attributes: {
          label: 'account test',
          account: access_key,
          comment: 'arn:aws:iam::012345678901:mfa/ec2-user',
          updated_at: Time.parse('2016-12-01T22:20:01Z')
        },
        password: 'biglongbase64'
      )
    end
    let(:role) do
      instance_double(
        'HashMap',
        attributes: { label: 'role role', account: role_arn },
        password: ''
      )
    end
    let(:session_key) do
      instance_double(
        'HashMap',
        attributes: {
          label: 'session-key test',
          account: 'ASIATESTTEST',
          comment: 'role role',
          updated_at: Time.parse('2016-12-01T22:20:01Z')
        },
        password: 'bigerlongbase64'
      )
    end
    let(:session_token) do
      instance_double(
        'HashMap',
        attributes: {
          label: 'session-token test',
          account: Time.parse('2016-12-20T22:20:01Z').to_i.to_s,
          comment: 'role'
        },
        password: 'evenlongerbase64token'
      )
    end
    let(:all_list) { [item, role, session_key, session_token] }
    let(:keychain) { instance_double('Keychain::Keychain', generic_passwords: all_list, lock_interval: 300) }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read)
        .with(/\.awskeyring/)
        .and_return('{ "awskeyring": "test", "keyage": 90 }')
      allow(Keychain).to receive(:open).and_return(keychain)
      allow(all_list).to receive(:all).and_return(all_list)
      allow(all_list).to receive(:where).and_return([nil])
      allow(all_list).to receive(:where).with(label: 'account test').and_return([item])
      allow(all_list).to receive(:where).with(account: access_key).and_return([item])
      allow(all_list).to receive(:where).with(label: 'role role').and_return([role])
      allow(all_list).to receive(:where).with(account: role_arn).and_return([role])
      allow(all_list).to receive(:where).with(label: 'session-key test').and_return([session_key])
      allow(all_list).to receive(:where).with(label: 'session-token test').and_return([session_token])
      allow(session_key).to receive(:delete)
      allow(session_token).to receive(:delete)
      allow(Time).to receive(:new).and_return(Time.parse('2016-12-01T22:20:02Z'))
    end

    it 'returns a hash with the creds and token' do
      test_hash = nil
      expect do
        test_hash = awskeyring.get_valid_creds(account: 'test', no_token: false)
      end.to output(/# Using temporary session credentials/).to_stdout
      expect(test_hash).to eq(
        account: 'test',
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token',
        expiry: Time.parse('2016-12-20T22:20:01Z').to_i,
        mfa: nil,
        updated: Time.parse('2016-12-01T22:20:01Z')
      )
    end

    it 'returns a hash with the only the creds' do
      expect(awskeyring.get_valid_creds(account: 'test', no_token: true)).to eq(
        account: 'test',
        key: access_key,
        secret: 'biglongbase64',
        token: nil,
        expiry: nil,
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user',
        updated: Time.parse('2016-12-01T22:20:01Z')
      )
    end

    it 'returns a hash with the role' do
      expect(awskeyring.get_role_arn(role_name: 'role')).to eq(
        'arn:aws:iam::012345678901:role/test'
      )
    end

    it 'validates an account name' do
      expect { awskeyring.account_exists('test') }.not_to raise_error
    end

    it 'invalidates an account name' do
      expect { awskeyring.account_not_exists('test') }.to raise_error('Account already exists')
    end

    it 'validates an token name' do
      expect { awskeyring.token_exists('test') }.not_to raise_error
    end

    it 'invalidates an access key' do
      expect { awskeyring.access_key_not_exists('test') }.to raise_error('Invalid Access Key')
    end

    it 'finds an existing access key' do
      expect { awskeyring.access_key_not_exists(access_key) }.to raise_error('Access KEY already exists')
    end

    it 'lists all accounts' do
      expect(awskeyring.list_account_names).to eq(
        ['test']
      )
    end

    it 'lists all tokens' do
      expect(awskeyring.list_token_names).to eq(
        ['test']
      )
    end

    it 'validates a role name' do
      expect { awskeyring.role_exists('role') }.not_to raise_error
    end

    it 'invalidates a role name' do
      expect { awskeyring.role_not_exists('role') }.to raise_error('Role already exists')
    end

    it 'invalidates a role arn' do
      expect { awskeyring.role_arn_not_exists('role') }.to raise_error('Invalid Role ARN')
    end

    it 'finds a existing role arn' do
      expect { awskeyring.role_arn_not_exists(role_arn) }.to raise_error('Role ARN already exists')
    end

    it 'lists all roles' do
      expect(awskeyring.list_role_names).to eq(
        ['role']
      )
    end

    it 'lists all roles with detail' do
      expect(awskeyring.list_role_names_plus).to eq(
        ["role\tarn:aws:iam::012345678901:role/test"]
      )
    end
  end

  context 'when we try to find the latest version' do
    let(:net_http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:get)
        .and_return(
          instance_double(
            'HashMap',
            body: '{"version":"1.2.3"}'
          )
        )
      allow(net_http).to receive(:use_ssl=)
    end

    it 'return the version number' do
      expect(awskeyring.latest_version).to eq('1.2.3')
    end
  end
end
