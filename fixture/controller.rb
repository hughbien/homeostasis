require 'rubygems'
require '../lib/homeostasis/asset'
require '../lib/homeostasis/env'
require '../lib/homeostasis/path'
require '../lib/homeostasis/front'

Homeostasis::Asset.concat 'all.css', %w(styles.css)

before /.*.html.haml/ do
end
