# Awskeyring

![Awskeyring](https://raw.githubusercontent.com/tristanmorgan/awskeyring/main/awskeyring-144.png)

* ![Build Passing](https://github.com/tristanmorgan/awskeyring/actions/workflows/ruby.yml/badge.svg)
* [![Gem Version](https://img.shields.io/gem/v/awskeyring)](https://badge.fury.io/rb/awskeyring)
* [![license MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
* [![All Downloads](https://img.shields.io/gem/dt/awskeyring)](https://rubygems.org/gems/awskeyring)
* [![Version Downloads](https://img.shields.io/gem/dtv/awskeyring)](https://rubygems.org/gems/awskeyring)
* [![Documentation](https://img.shields.io/badge/yard-docs-brightgreen.svg)](https://www.rubydoc.info/gems/awskeyring)

Awskeyring is a small tool to manage AWS account keys in the macOS Keychain. It has
grown to incorporate a lot of [features](https://github.com/tristanmorgan/awskeyring/wiki/Awskeyring-features).

## Motivation

The motivation of this application is to provide a local secure store of AWS
credentials using specifically in the macOS Keychain, to have them easily accessed
from the Terminal, and to provide useful functions like assuming roles and opening
the AWS Console from the cli.
For Enterprise environments there are better suited tools to use
like [HashiCorp Vault](https://vaultproject.io/).

## Installation

Install it with:

    $ gem install awskeyring --user-install

or via [homebrew gem](https://github.com/sportngin/brew-gem):

    $ brew gem install awskeyring

## Wiki

Please see the [Wiki](https://github.com/tristanmorgan/awskeyring/wiki) for full usage instructions and tips.

## Quick start

First you need to initialise your keychain to hold your AWS credentials.

    $ awskeyring initialise

Then add your keys to it.

    $ awskeyring add personal-aws

Now your keys are stored safely in the macOS keychain. To print environment variables run...

    $ awskeyring env personal-aws

Alternatively you can create a profile using the credential_process config variable. See the
[AWS CLI Config docs](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#cli-aws-help-config-vars) for
more details on this config option.

    [profile personal]
    region = us-west-1
    credential_process = /usr/local/bin/awskeyring json personal-aws

## Usage

The CLI is using [Thor](http://whatisthor.com) with help provided interactively.

    Awskeyring commands:
      awskeyring --version, -v                # Prints the version
      awskeyring add ACCOUNT                  # Adds an ACCOUNT to the keyring
      awskeyring add-role ROLE                # Adds a ROLE to the keyring
      awskeyring console ACCOUNT              # Open the AWS Console for the ACCOUNT
      awskeyring env ACCOUNT                  # Outputs bourne shell environment exports for an ACCOUNT
      awskeyring exec ACCOUNT command...      # Execute a COMMAND with the environment set for an ACCOUNT
      awskeyring help [COMMAND]               # Describe available commands or one specific command
      awskeyring import ACCOUNT               # Import an ACCOUNT to the keyring from ~/.aws/credentials
      awskeyring initialise                   # Initialises a new KEYCHAIN
      awskeyring json ACCOUNT                 # Outputs AWS CLI compatible JSON for an ACCOUNT
      awskeyring list                         # Prints a list of accounts in the keyring
      awskeyring list-role                    # Prints a list of roles in the keyring
      awskeyring remove ACCOUNT               # Removes an ACCOUNT from the keyring
      awskeyring remove-role ROLE             # Removes a ROLE from the keyring
      awskeyring remove-token ACCOUNT         # Removes a token for ACCOUNT from the keyring
      awskeyring rotate ACCOUNT               # Rotate access keys for an ACCOUNT
      awskeyring token ACCOUNT [ROLE] [CODE]  # Create an STS Token from a ROLE or an mfa CODE
      awskeyring update ACCOUNT               # Updates an ACCOUNT in the keyring

and autocomplete that can be installed with:

    $ complete -C /usr/local/bin/awskeyring awskeyring

There are also short forms of most commands if you prefer:

    $ awskeyring ls

To set your environment easily the following bash function helps:

    awsenv() { eval "$(awskeyring env ${@:-$AWS_ACCOUNT_NAME})"; }

## Development

After checking out the repo, run `bundle update` to install dependencies. Then, run `bundle exec rake` to run the
tests. Run `bundle exec awskeyring` to use the gem in this directory, ignoring other installed copies of this gem.
Awskeyring is tested against the last two versions of Ruby shipped with macOS.

To install this gem onto your local machine, run `bundle exec rake install`.

## Security

If you believe you have found a security issue in Awskeyring, please responsibly disclose by contacting me at
[tristan.morgan@gmail.com](mailto:tristan.morgan@gmail.com). Awskeyring is a Ruby script and as such Ruby is whitelisted
to access your "awskeyring" keychain. Use a strong password and keep the unlock time short.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/tristanmorgan/awskeyring](https://github.com/tristanmorgan/awskeyring).
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](https://contributor-covenant.org) code of conduct.

### Contributors

* Tristan [tristanmorgan](https://github.com/tristanmorgan)
* Adam Sir [AzySir](https://github.com/AzySir)
* Vito Giarrusso [thtliife](https://github.com/thtliife)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

