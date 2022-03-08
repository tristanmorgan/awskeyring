# frozen_string_literal: true

# https://github.com/simplecov-ruby/simplecov/issues/557
# due to a clash between Gem conventions and how SimpleCov
# works, this test doesn't show up in the coverage report.

require 'spec_helper'
require_relative '../../../lib/awskeyring/version'

describe Awskeyring do
  subject(:awskeyring) { described_class }

  context 'when getting the latest version' do
    let(:request_body) { '{"version":"1.2.3"}' }
    let(:net_http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:get)
        .and_return(
          instance_double(
            'HashMap',
            body: request_body
          )
        )
      allow(net_http).to receive(:use_ssl=)
    end

    it 'has a version number' do
      expect(Awskeyring::VERSION).not_to be_nil
    end

    it 'has a homepage url' do
      expect(Awskeyring::HOMEPAGE).not_to be_nil
    end

    it 'has a version_number url' do
      expect(Awskeyring::GEM_VERSION_URL).not_to be_nil
    end

    it 'fetches the latest version number' do
      expect(awskeyring.latest_version).to eq('1.2.3')
    end
  end
end
