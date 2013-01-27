if ENV['HOMEOSTASIS_COVERAGE']
  require 'simplecov'
  SimpleCov.command_name 'minitest'
  SimpleCov.start
end

require 'rubygems'
require 'stasis'
require 'minitest/autorun'

ENV['HOMEOSTASIS_UNREGISTER'] = '1'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'homeostasis'))

class HomeostasisTest < MiniTest::Unit::TestCase
  TEST_DIR = File.expand_path(File.dirname(__FILE__))

  def setup
    @stasis = Stasis.new(File.join(TEST_DIR, '..', 'fixture'))
    @asset = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Asset) }
    @front = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Front) }
    @trail = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Trail) }
    @sitemap = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Sitemap) }
    @blog = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Blog) }
    @stasis.render
  end

  def teardown
    FileUtils.remove_dir(@stasis.destination, true)
  end

  def test_asset
    contents = File.read(dest('index.html'))

    # replaced photo.jpg
    version = Homeostasis::Asset.version(root('photo.jpg'))
    assert_equal(40, version.length)
    assert_equal(
      "photo.#{version}.jpg",
      Homeostasis::Asset.stamped('photo.jpg', version))
    refute(File.exists?(dest('photo.jpg')))
    assert(File.exists?(dest("photo.#{version}.jpg")))
    refute(contents =~ /photo\.jpg/)
    assert(contents =~ /photo\.#{version}\.jpg/)

    # concat style.css => all.css
    version = Homeostasis::Asset.version(root('styles.css'))
    assert_equal(40, version.length)
    assert_equal(
      "all.#{version}.css",
      Homeostasis::Asset.stamped('all.css', version))
    refute(File.exists?(dest('styles.css')))
    assert(File.exists?(dest("all.#{version}.css")))
    refute(contents =~ /styles\.css/)
    refute(contents =~ /all\.css/)
    assert(contents =~ /all\.#{version}\.css/)
  end

  def test_front
    assert_equal(
     ['blog/2012-01-01-hello-world.html.md',
      'blog/2012-01-02-second-post.html.md',
      'blog/index.html.haml',
      'index.html.haml',
      'layout.html.haml',
      'page.html.md'],
     @front.front_site.keys.sort)

    page = @front.front_site['page.html.md']
    assert_equal('/page/', page[:path])
    assert_equal('Page', page[:title])

    index = @front.front_site['index.html.haml']
    assert_equal('/', index[:path])
    assert_equal('Index', index[:title])

    hello_world = @front.front_site['blog/2012-01-01-hello-world.html.md']
    assert_equal('/hello-world/', hello_world[:path])
    assert_equal('Hello World', hello_world[:title])
    assert_equal('2012-01-01', hello_world[:date].strftime('%Y-%m-%d'))

    second_post = @front.front_site['blog/2012-01-02-second-post.html.md']
    assert_equal('/second-post/', second_post[:path])
    assert_equal('Second Post', second_post[:title])
    assert_equal('2012-01-02', second_post[:date].strftime('%Y-%m-%d'))

  end

  def test_trail
    assert(File.exists?(dest("index.html")))
    assert(File.exists?(dest("page/index.html")))
    refute(File.exists?(dest("page.html")))

    @stasis.plugins.delete_if { |p| p.is_a?(Homeostasis::Trail) }
    @stasis.render
    assert(File.exists?(dest("page.html")))
    refute(File.exists?(dest("page/index.html")))
  end

  def test_sitemap
    assert(File.exists?(dest("sitemap.xml")))

    xml = File.read(dest("sitemap.xml"))
    assert(xml =~ /<loc>http:\/\/local\.fixture\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/page\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/blog\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/hello-world\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/second-post\/<\/loc>/)
    assert_equal(0, xml.scan("<lastmod>").length)
  end

  def test_blog
    assert(Homeostasis::Blog::DATE_REGEX =~ '2012-01-01-title')
    assert_equal('2012-01-01', $1)

    assert(File.exists?(dest("/blog/index.html")))
    assert(File.exists?(dest("/hello-world/index.html")))
    assert(File.exists?(dest("/second-post/index.html")))
    refute(File.exists?(dest("/blog/2012-01-01-hello-world.html")))
    refute(File.exists?(dest("/blog/2012-01-02-second-post.html")))

    posts = @blog.blog_posts
    assert_equal(
      ['Second Post', 'Hello World'],
      posts.map { |p| p[:title] })
    assert_equal(
      ['/second-post/', '/hello-world/'],
      posts.map { |p| p[:path] })
    assert_equal(
      ['2012-01-02', '2012-01-01'],
      posts.map { |p| p[:date].strftime('%Y-%m-%d') })

    assert(File.exists?(dest("/blog/rss.xml")))
    rss = File.read(dest("/blog/rss.xml"))
    assert_match("Sun, 01 Jan 2012 0:00:01 #{Time.new.zone}", rss)
    assert_match("Mon, 02 Jan 2012 0:00:01 #{Time.new.zone}", rss)
  end

  private
  def dest(path)
    File.join(@stasis.destination, path)
  end

  def root(path)
    File.join(@stasis.root, path)
  end
end
