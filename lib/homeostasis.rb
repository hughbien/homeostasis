module Homeostasis
  VERSION = '0.0.9'
end

if !ENV['HOMEOSTASIS_BUILD']
  require File.join(File.dirname(__FILE__), 'homeostasis', 'asset')
  require File.join(File.dirname(__FILE__), 'homeostasis', 'front')
  require File.join(File.dirname(__FILE__), 'homeostasis', 'trail')
  require File.join(File.dirname(__FILE__), 'homeostasis', 'blog')
end
