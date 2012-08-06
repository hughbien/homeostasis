require 'rubygems'
require '../lib/homeostasis'

Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Blog.config(
  'blog',
  'http://local.fixture/blog',
  'Local Fixture',
  'A place to test Homeostasis')
Homeostasis::Sitemap.url 'http://local.fixture'

layout /.*.html(\.haml|\.md)?/ => 'layout.html.haml'
