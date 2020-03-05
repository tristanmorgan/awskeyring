# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'ronn'
require 'github_changelog_generator/task'
require 'yard'

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'servian'
  config.project = 'awskeyring'
  config.future_release = "v#{Awskeyring::VERSION}"
  config.since_tag = 'v0.10.0'
end

RuboCop::RakeTask.new do |rubocop|
  rubocop.options = ['-D']
  rubocop.requires << 'rubocop-performance'
  rubocop.requires << 'rubocop-rake'
  rubocop.requires << 'rubocop-rspec'
  rubocop.requires << 'rubocop-rubycw'
end

RSpec::Core::RakeTask.new(:spec)

desc 'Check filemode bits'
task :filemode do
  files = `git ls-files -z`.split("\x0")
  failure = false
  files.each do |file|
    mode = File.stat(file).mode
    print '.'
    if (mode & 0x7) != (mode >> 3 & 0x7)
      puts file
      failure = true
    end
  end
  abort 'Error: Incorrect file mode found' if failure
  print "\n"
end

desc 'generate manpage'
task :ronn do
  puts 'Writing manpage'
  roff_text = Ronn::Document.new('man/awskeyring.5.ronn').to_roff
  File.write('man/awskeyring.5', roff_text)
  puts "done\n\n"
end

YARD::Rake::YardocTask.new do |t|
  t.options = ['--fail-on-warning', '--no-progress']
  t.stats_options = ['--list-undoc']
end

task default: %i[filemode rubocop spec ronn yard]
