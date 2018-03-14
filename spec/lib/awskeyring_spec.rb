require 'spec_helper'

describe Awskeyring do
  context 'When there is no config file' do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(false)
    end

    it 'has a version number' do
      expect(Awskeyring::VERSION).not_to be nil
    end

    it 'has a default preferences file' do
      expect(Awskeyring::PREFS_FILE).not_to be nil
    end

    it 'can not load preferences' do
      expect(subject.prefs).to eq({})
    end
  end

  context 'When there is a config file' do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?)
        .with(/\.awskeyring/)
        .and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read)
        .with(/\.awskeyring/)
        .and_return('{ "awskeyring": "test" }')
    end

    it 'loads preferences from a file' do
      expect(subject.prefs).to eq('awskeyring' => 'test')
    end
  end

  context 'When there is accounts and roles' do
    let(:item) do
      double(
        attributes: { label: 'account test', account: 'AKIATESTTEST' },
        password: 'biglongbase64'
      )
    end
    let(:role) do
      double(
        attributes: { label: 'role test', account: 'arn:aws:iam::012345678901:role/test' },
        password: ''
      )
    end

    before do
      all_list = double([item, role])
      allow(all_list).to receive(:where).and_return([nil])
      allow(all_list).to receive(:where).with(label: 'account test').and_return([item])
      allow(all_list).to receive(:where).with(label: 'role test').and_return([role])
      allow(subject).to receive(:all_items).and_return(all_list)
      allow(item).to receive(:delete)
      allow(role).to receive(:delete)
    end

    it 'returns a hash with the creds' do
      expect(subject.get_valid_creds(account: 'test')).to eq(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil
      )
      expect(subject.get_account_hash(account: 'test')).to eq(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        mfa: nil
      )
    end

    it 'tries to delete an account by name' do
      expect(item).to receive(:delete)
      expect do
        subject.delete_account(account: 'test', message: 'test delete message')
      end.to output(/test delete message/).to_stdout
    end

    it 'returns a hash with the role' do
      expect(subject.get_role_arn(role_name: 'test')).to eq(
        'arn:aws:iam::012345678901:role/test'
      )
    end

    it 'tries to delete a role by name' do
      expect(role).to receive(:delete)
      expect do
        subject.delete_role(role_name: 'test', message: 'test delete message')
      end.to output(/test delete message/).to_stdout
    end
  end

  context 'When there is accounts and roles and tokens' do
    let(:item) do
      double(
        attributes: {
          label: 'account test',
          account: 'AKIATESTTEST',
          comment: 'arn:aws:iam::012345678901:mfa/ec2-user'
        },
        password: 'biglongbase64'
      )
    end
    let(:role) do
      double(
        attributes: { label: 'role test', account: 'arn:aws:iam::012345678901:role/test' },
        password: ''
      )
    end
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
      all_list = double([item, role])
      allow(all_list).to receive(:where).and_return([nil])
      allow(all_list).to receive(:where).with(label: 'account test').and_return([item])
      allow(all_list).to receive(:where).with(label: 'role test').and_return([role])
      allow(all_list).to receive(:where).with(label: 'session-key test').and_return([session_key])
      allow(all_list).to receive(:where).with(label: 'session-token test').and_return([session_token])
      allow(subject).to receive(:all_items).and_return(all_list)
      allow(subject).to receive(:delete_expired).and_return([session_key, session_token])
      allow(item).to receive(:delete)
      allow(role).to receive(:delete)
      allow(session_key).to receive(:delete)
      allow(session_token).to receive(:delete)
    end

    it 'returns a hash with the creds and token' do
      test_hash = nil
      expect do
        test_hash = subject.get_valid_creds(account: 'test')
      end.to output(/# Using temporary session credentials/).to_stdout
      expect(test_hash).to eq(
        account: 'test',
        key: 'ASIATESTTEST',
        secret: 'bigerlongbase64',
        token: 'evenlongerbase64token'
      )
      expect(subject.get_account_hash(account: 'test')).to eq(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        mfa: 'arn:aws:iam::012345678901:mfa/ec2-user'
      )
    end

    it 'returns a hash with the role' do
      expect(subject.get_role_arn(role_name: 'test')).to eq(
        'arn:aws:iam::012345678901:role/test'
      )
    end
  end
end
