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

task default: %i[filemode rubocop spec]
