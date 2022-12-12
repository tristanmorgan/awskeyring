# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'awskeyring/version'

Gem::Specification.new do |spec|
  spec.name          = 'awskeyring'
  spec.version       = Awskeyring::VERSION
  spec.authors       = ['Tristan Morgan']
  spec.email         = 'tristan.morgan@gmail.com'

  spec.summary       = 'Manages AWS credentials in the macOS keychain'
  spec.description   = 'Manages AWS credentials in the macOS keychain'
  spec.homepage      = Awskeyring::HOMEPAGE
  spec.licenses      = ['MIT']

  spec.files         = %w[awskeyring.gemspec README.md LICENSE.txt] + Dir['exe/*', 'lib/**/*.rb', 'man/*.5', 'i18n/*']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata = {
    'bug_tracker_uri' => "#{Awskeyring::HOMEPAGE}/issues",
    'changelog_uri' => "#{Awskeyring::HOMEPAGE}/blob/main/CHANGELOG.md",
    'documentation_uri' => "https://rubydoc.info/gems/#{spec.name}/#{Awskeyring::VERSION}",
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => "#{Awskeyring::HOMEPAGE}/tree/v#{Awskeyring::VERSION}",
    'wiki_uri' => "#{Awskeyring::HOMEPAGE}/wiki"
  }

  spec.add_dependency('aws-sdk-iam')
  spec.add_dependency('i18n')
  spec.add_dependency('ruby-keychain')
  spec.add_dependency('thor')
end
