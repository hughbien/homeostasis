ENV['HOMEOSTASIS_BUILD'] = '1'
require File.join(File.dirname(__FILE__), 'lib', 'homeostasis')
 
Gem::Specification.new do |s|
  s.name        = 'homeostasis'
  s.version     = Homeostasis::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Hugh Bien']
  s.email       = ['hugh@hughbien.com']
  s.homepage    = 'https://github.com/hughbien/homeostasis'
  s.summary     = 'Stasis plugin for asset stamping and more.'
  s.description = 'Provides asset stamping using git revisions, ' +
                  'environments, and a few view helpers.'
 
  s.required_rubygems_version = '>= 1.3.6'
  s.files         = Dir.glob('*.md') + Dir.glob('lib/**/*.rb')
  s.require_paths = ['lib']
end
