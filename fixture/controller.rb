require 'rubygems'
require 'bluecloth'
require '../lib/homeostasis'

Homeostasis::Asset.concat 'all.css', %w(styles.css)
Homeostasis::Blog.config(
  :directory => 'blog',
  :path => '',
  :url => 'http://local.fixture',
  :title => 'Local Fixture',
  :desc => 'A place to test Homeostasis')
Homeostasis::Sitemap.config(
  :url => 'http://local.fixture',
  :lastmod => false)

layout /.*.html(\.haml|\.md)?/ => 'layout.html.haml'

before_all do
  Homeostasis::Event.instance_variable_set(:@before_fixture, [1])
end

before_all do
  fixture = Homeostasis::Event.instance_variable_get(:@before_fixture)
  fixture << 2
end

after_all do
  Homeostasis::Event.instance_variable_set(:@after_fixture, [1])
end

after_all do
  fixture = Homeostasis::Event.instance_variable_get(:@after_fixture)
  fixture << 2
end
