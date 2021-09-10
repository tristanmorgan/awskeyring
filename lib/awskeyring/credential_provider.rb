# frozen_string_literal: true

require 'aws-sdk-core'
require 'awskeyring'

module Awskeyring
  # Provide a credential provider for use as a library, eg.
  #     require 'awskeyring/credential_provider'
  #     client = Aws::STS::Client.new(
  #       credentials: Awskeyring::CredentialProvider.new("company-acc")
  #     )
  class CredentialProvider
    include Aws::CredentialProvider

    attr_accessor :account

    def initialize(account)
      @account = account
    end

    # returns a new Aws::Credentials object
    def credentials
      cred = Awskeyring.get_valid_creds(account: account)
      Aws::Credentials.new(cred[:key],
                           cred[:secret],
                           cred[:token])
    end
  end
end
