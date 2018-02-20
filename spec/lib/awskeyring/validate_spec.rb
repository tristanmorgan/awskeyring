require 'spec_helper'
require_relative '../../../lib/awskeyring/validate'

describe Awskeyring do
  context 'When validating inputs' do
    let(:test_key) { 'AKIA1234567890ABCDEF' }
    let(:test_broken_key) { 'AKIA1234567890' }

    it 'validates an access key' do
      expect { subject.access_key(test_key) }.to_not raise_error
    end

    it 'invalidates an access key' do
      expect { subject.access_key(test_broken_key) }.to raise_error('Invalid Access Key')
    end

    let(:test_secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FEQW3IUJV' }
    let(:test_broken_secret) { 'AbCkTEsTAAAi8ni0987ASDFwer23j14FE' }

    it 'validates an secret access key' do
      expect { subject.secret_access_key(test_secret) }.to_not raise_error
    end

    it 'invalidates an secret access key' do
      expect { subject.secret_access_key(test_broken_secret) }.to raise_error('Secret Access Key is not 40 chars')
    end
  end
end
