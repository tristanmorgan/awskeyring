# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/awskeyring/input'

describe Awskeyring::Input do
  subject(:input) { described_class }

  context 'when inputting a secret key' do
    it 'asks for a secret' do
      allow($stdin).to receive(:getch).and_return('A', 'B', 'C', '1', '2', '3', "\n")
      expect do
        input.read_secret('   secret access key: ')
      end.to output("   secret access key: ******\n").to_stdout
    end

    it 'asks for a secret and delete a few characters' do
      allow($stdin).to receive(:getch)
        .and_return('A', 'B', 'C', '1', 'm', 'i', 's', 's', "\b", "\b", "\b", "\b", '2', '3', "\n")
      expect do
        input.read_secret('   secret access key: ')
      end.to output("   secret access key: ********\b\e[P\b\e[P\b\e[P\b\e[P**\n").to_stdout
    end

    it 'asks for a secret and canceled the operation' do
      allow($stdin).to receive(:getch)
        .and_return('A', 'B', 'C', '1', "\u0003")
      expect do
        input.read_secret('   secret access key: ')
      end.to raise_error(SystemExit).and output('   secret access key: ****').to_stdout
    end
  end
end
