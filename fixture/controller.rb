require 'rubygems'
require '../lib/homeostasis'

Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Blog.directory 'blog'

layout /.*.html(\.haml|\.md)?/ => 'layout.html.haml'

before /.*.html(\.haml|\.md)/ do
end
