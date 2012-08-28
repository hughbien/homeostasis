require 'rubygems'
require '../lib/homeostasis'

Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Blog.config(
  'blog',
  'http://local.fixture/blog',
  'Local Fixture',
  'A place to test Homeostasis')
Homeostasis::Sitemap.config(
  :url => 'http://local.fixture',
  :lastmod => false)

layout /.*.html(\.haml|\.md)?/ => 'layout.html.haml'
