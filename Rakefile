ENV['HOMEOSTASIS_UNREGISTER'] = '1'
require File.join(File.dirname(__FILE__), 'lib', 'homeostasis')
require File.join(File.dirname(__FILE__), 'lib', 'version')

task :default => :test

desc 'run tests'
task :test do
  puts `ruby test/homeostasis_test.rb`
end

desc 'run tests with coverage report'
task :coverage do
  ENV['HOMEOSTASIS_COVERAGE'] = '1'
  puts `ruby test/homeostasis_test.rb`
end

desc 'build gem'
task :build do
  `gem build homeostasis.gemspec`
end

desc 'clean generated files'
task :clean do
  rm Dir.glob('*.gem')
  rm_rf 'coverage'
end

desc 'push gem to production'
task :push => :build do
  `gem push homeostasis-#{Homeostasis::VERSION}.gem`
end

namespace :site do
  task :default => :build

  desc 'Build site'
  task :build do
    `cd site && stasis`
  end

  desc 'Push site to homeostasisrb.com'
  task :push => [:clean, :build] do
    `rsync -avz --delete site/public/ homeostasisrb.com:webapps/homeostasisrb`
  end

  desc 'Remove built site artifacts'
  task :clean do
    rm_rf 'site/public'
  end
end
