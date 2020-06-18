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
  rubocop.options = %w[-D --enable-pending-cops]
  rubocop.requires << 'rubocop-performance'
  rubocop.requires << 'rubocop-rake'
  rubocop.requires << 'rubocop-rspec'
  rubocop.requires << 'rubocop-rubycw'
end

desc 'Run RSpec code examples'
task :spec do
  puts 'Running RSpec...'
  require 'rspec/core'
  runner = RSpec::Core::Runner
  xcode = runner.run(%w[--pattern spec/**{,/*/**}/*_spec.rb --order rand --format documentation --color])
  abort 'RSpec failed' if xcode.positive?
end

desc 'Check filemode bits'
task :filemode do
  puts 'Running FileMode...'
  files = Set.new(`git ls-files -z`.split("\x0"))
  dirs = Set.new(files.map { |file| File.dirname(file) })
  failure = []
  files.merge(dirs).each do |file|
    mode = File.stat(file).mode
    print '.'
    failure << file if (mode & 0x7) != (mode >> 3 & 0x7)
  end
  abort "\nError: Incorrect file mode found\n#{failure.join("\n")}" unless failure.empty?
  print "\n"
end

desc 'generate manpage'
task :ronn do
  puts 'Running Ronn...'
  roff_text = Ronn::Document.new('man/awskeyring.5.ronn').to_roff
  File.write('man/awskeyring.5', roff_text)
  puts "done\n\n"
end

YARD::Rake::YardocTask.new do |t|
  t.options = ['--fail-on-warning', '--no-progress']
  t.stats_options = ['--list-undoc']
end

task default: %i[filemode rubocop spec ronn yard]
