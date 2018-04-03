# Awskeyring

* [![Build Status](https://travis-ci.org/vibrato/awskeyring.svg?branch=master)](https://travis-ci.org/vibrato/awskeyring)
* [![Gem Version](https://badge.fury.io/rb/awskeyring.svg)](https://badge.fury.io/rb/awskeyring)
* [![license MIT](http://img.shields.io/badge/license-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
* [![All Downloads](http://ruby-gem-downloads-badge.herokuapp.com/awskeyring?type=total)](https://rubygems.org/gems/awskeyring)
* [![Version Downloads](http://ruby-gem-downloads-badge.herokuapp.com/awskeyring?label=downloads-current-version)](https://rubygems.org/gems/awskeyring)
* [![Documentation](http://img.shields.io/badge/yard-docs-brightgreen.svg)](http://www.rubydoc.info/gems/awskeyring)

Awskeyring is a small tool to manage AWS account keys in the macOS Keychain.

## Motivation

The motivation of this application is to provide a local secure store of AWS
credentials using specifically in the macOS Keychain, to have them easily accessed
from the Terminal, and to provide useful functions like assuming roles and opening
the AWS Console from the cli.
For Enterprise environments there are better suited tools to use
like [HashiCorp Vault](https://vaultproject.io/).

## Quick start

First you need to initialise your keychain to hold your AWS credentials.

    awskeyring initialise

Then add your keys to it.

    awskeyring add personal-aws

Now your keys are stored safely in the macOS keychain. To print environment variables run...

    awskeyring env personal-aws

See below and in the wiki for more details on usage.

## Installation

Install it with:

    $ gem install awskeyring --user-install

## Usage

The CLI is using [Thor](http://whatisthor.com) with help provided interactively.

    Commands:
      awskeyring --version, -v               # Prints the version
      awskeyring add ACCOUNT                 # Adds an ACCOUNT to the keyring
      awskeyring add-role ROLE               # Adds a ROLE to the keyring
      awskeyring console ACCOUNT             # Open the AWS Console for the ACCOUNT
      awskeyring env ACCOUNT                 # Outputs bourne shell environment exports for an ACCOUNT
      awskeyring exec ACCOUNT command...     # Execute a COMMAND with the environment set for an ACCOUNT
      awskeyring help [COMMAND]              # Describe available commands or one specific command
      awskeyring initialise                  # Initialises a new KEYCHAIN
      awskeyring list                        # Prints a list of accounts in the keyring
      awskeyring list-role                   # Prints a list of roles in the keyring
      awskeyring remove ACCOUNT              # Removes an ACCOUNT from the keyring
      awskeyring remove-role ROLE            # Removes a ROLE from the keyring
      awskeyring remove-token ACCOUNT        # Removes a token for ACCOUNT from the keyring
      awskeyring rotate ACCOUNT              # Rotate access keys for an ACCOUNT
      awskeyring token ACCOUNT [ROLE] [MFA]  # Create an STS Token from a ROLE or an MFA code

and autocomplete that can be installed with:

    $ complete -C /usr/local/bin/awskeyring awskeyring

To set your environment easily the following bash function helps:

    awsenv() { eval "$(awskeyring env $1)"; }

## Development

After checking out the repo, run `bundle update` to install dependencies. Then, run `rake` to run the tests. Run `bundle exec awskeyring` to use the gem in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vibrato/awskeyring. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

