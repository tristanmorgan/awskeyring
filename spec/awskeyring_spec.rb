require 'spec_helper'

describe Awskeyring do
  it 'has a version number' do
    expect(Awskeyring::VERSION).not_to be nil
  end

  it 'has a default preferences file' do
    expect(Awskeyring::PREFS_FILE).not_to be nil
  end

  it 'can not load preferences' do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?)
      .with(/\.awskeyring/)
      .and_return(false)

    expect(subject.prefs).to eq({})
  end

  it 'loads preferences from a file' do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?)
      .with(/\.awskeyring/)
      .and_return(true)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read)
      .with(/\.awskeyring/)
      .and_return('{ "awskeyring": "test" }')

    expect(subject.prefs).to eq('awskeyring' => 'test')
  end
end
