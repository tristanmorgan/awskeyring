# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/awskeyring/credential_provider'

describe Awskeyring::CredentialProvider do
  subject(:credential_provider) { described_class }

  context 'when getting credentials' do
    before do
      allow(Awskeyring).to receive(:get_valid_creds).with(account: 'test').and_return(
        account: 'test',
        key: 'AKIATESTTEST',
        secret: 'biglongbase64',
        token: nil,
        updated: Time.parse('2011-08-01T22:20:01Z')
      )
    end

    it 'gets a credential_provider object' do
      expect(credential_provider.new('test').credentials)
        .to be_a Aws::Credentials
    end
  end
end
