require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'github_changelog_generator/task'

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.future_release = "v#{Awskeyring::VERSION}"
end

RuboCop::RakeTask.new do |rubocop|
  rubocop.options = ['-D']
end

RSpec::Core::RakeTask.new(:spec)

task default: %i[rubocop spec]
