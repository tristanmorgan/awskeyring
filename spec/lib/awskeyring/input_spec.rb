# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/awskeyring/input'

describe Awskeyring::Input do
  subject(:input) { described_class }

  context 'when inputting a secret key' do
    before do
      allow(STDIN).to receive(:getch).and_return('A', 'B', 'C', '1', '2', '3', "\n")
    end

    it 'asks for a secret' do
      expect do
        input.read_secret('   secret access key: ')
      end.to output("   secret access key: ******\n").to_stdout
    end
  end
end
