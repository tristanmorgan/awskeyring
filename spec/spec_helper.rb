# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  minimum_coverage 90
  add_filter '/spec/'
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'awskeyring'
