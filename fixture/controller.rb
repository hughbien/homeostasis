require 'rubygems'
require '../lib/homeostasis'

Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Blog.directory 'blog'
Homeostasis::Sitemap.url 'http://local.fixture'

layout /.*.html(\.haml|\.md)?/ => 'layout.html.haml'
