# Awskeyring

Awskeyring is a small tool to manage AWS account keys in the macOS Keychain.

## Installation

Install it with:

    $ gem install awskeyring

## Usage

The CLI is using [Thor](http://whatisthor.com) with help provided interactivly.

    Commands:
    awskeyring --version, -v               # Prints the version
    awskeyring add ACCOUNT                 # Adds an ACCOUNT to the keyring
    awskeyring add-role ROLE               # Adds a ROLE to the keyring
    awskeyring console ACCOUNT             # Open the AWS Console for the ACCOUNT
    awskeyring env ACCOUNT                 # Outputs bourne shell environment exports for an ACCOUNT
    awskeyring help [COMMAND]              # Describe available commands or one specific command
    awskeyring initialise                  # Initialises a new KEYCHAIN
    awskeyring list                        # Prints a list of accounts in the keyring
    awskeyring list-role                   # Prints a list of roles in the keyring
    awskeyring remove ACCOUNT              # Removes an ACCOUNT from the keyring
    awskeyring remove-role ROLE            # Removes a ROLE from the keyring
    awskeyring token ACCOUNT [ROLE] [MFA]  # Create an STS Token from a ROLE or an MFA code

and autocomplete that can be installed with:

    $ complete -C /usr/local/bin/aws-creds aws-creds

To set your environment easily the following function helps:

    awsenv() { eval "$(awskeyring env $1)"; }

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec awskeyring` to use the gem in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tristanmorgan/awskeyring. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

