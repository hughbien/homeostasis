require File.expand_path('lib/homeostasis', File.dirname(__FILE__))

task :default => :build

task :build do
  `gem build homeostasis.gemspec`
end

task :clean do
  rm Dir.glob('*.gem')
end

task :push => :build do
  `gem push homeostasis-#{Homeostasis::VERSION}.gem`
end
