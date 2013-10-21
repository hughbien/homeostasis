require 'rubygems'
require 'homeostasis'

Stasis::Options.set_template_option 'scss', Compass.sass_engine_options
Compass.configuration do |config|
  config.fonts_dir = 'font'
end
Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Sitemap.config(url: 'http://homeostasisrb.com')

ignore /\/_.*/
ignore /\/\.saas-cache\/.*/
ignore /.*\.scssc/
