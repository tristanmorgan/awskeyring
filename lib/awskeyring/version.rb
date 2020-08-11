# frozen_string_literal: true

require 'json'

# Awskeyring Module,
# Version const and query of latest.
module Awskeyring
  # The Gem's version number
  VERSION = '1.6.0'
  # The Gem's homepage
  HOMEPAGE = 'https://github.com/servian/awskeyring'

  # RubyGems Version url
  GEM_VERSION_URL = 'https://rubygems.org/api/v1/versions/awskeyring/latest.json'

  # Retrieve the latest version from RubyGems
  #
  def self.latest_version
    uri       = URI(GEM_VERSION_URL)
    request   = Net::HTTP.new(uri.host, uri.port)
    request.use_ssl = true
    JSON.parse(request.get(uri).body)['version']
  end
end
