ENV['HOMEOSTASIS_BUILD'] = '1'
require File.join(File.dirname(__FILE__), 'lib', 'homeostasis')

task :default => :test

task :test do
  filenames = ENV['TEST'] ? ENV['TEST'].split(' ') : Dir.glob('test/*_test.rb')
  filenames.each do |filename|
    require File.expand_path(filename)
  end
end

task :build do
  `gem build homeostasis.gemspec`
end

task :clean do
  rm Dir.glob('*.gem')
end

task :push => :build do
  `gem push homeostasis-#{Homeostasis::VERSION}.gem`
end
