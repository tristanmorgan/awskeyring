lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'awskeyring/version'

Gem::Specification.new do |spec|
  spec.name          = 'awskeyring'
  spec.version       = Awskeyring::VERSION
  spec.authors       = ['Tristan Morgan']
  spec.email         = ['tristan@vibrato.com.au']

  spec.summary       = 'Manages AWS credentials in the macOS keychain'
  spec.description   = 'Manages AWS credentials in the macOS keychain'
  spec.homepage      = 'https://github.com/vibrato/awskeyring'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/|^\..*}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency('aws-sdk-iam')
  spec.add_dependency('i18n')
  spec.add_dependency('ruby-keychain')
  spec.add_dependency('thor')
end
