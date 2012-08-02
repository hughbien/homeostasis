require 'rubygems'
require '../lib/homeostasis/asset'
require '../lib/homeostasis/env'
require '../lib/homeostasis/front'
require '../lib/homeostasis/trail'

Homeostasis::Asset.concat 'all.css', %w(styles.css)

layout /.*.html(\.haml|\.md)?/ => 'layout.html.haml'

before /.*.html(\.haml|\.md)/ do
end
