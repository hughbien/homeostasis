if ENV['HOMEOSTASIS_COVERAGE']
  require 'simplecov'
  SimpleCov.command_name 'minitest'
  SimpleCov.start
end

require 'stasis'
require 'cgi'
require 'redcarpet'
require 'erubis'
require 'haml'
require 'minitest/autorun'

ENV['HOMEOSTASIS_UNREGISTER'] = '1'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'homeostasis'))

class HomeostasisTest < Minitest::Test
  TEST_DIR = File.expand_path(File.dirname(__FILE__))

  def setup
    @stasis = Stasis.new(File.join(TEST_DIR, '..', 'fixture'))
    @asset = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Asset) }
    @event = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Event) }
    @front = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Front) }
    @multi = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Multi) }
    @trail = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Trail) }
    @sitemap = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Sitemap) }
    @blog = @stasis.plugins.find { |p| p.is_a?(Homeostasis::Blog) }
    @stasis.render
  end

  def teardown
    FileUtils.remove_dir(@stasis.destination, true)
  end

  def test_asset
    contents = Homeostasis::Helpers.read(dest('index.html'))

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

    # concat style.min.css => all.css
    version = Homeostasis::Asset.version(root('styles.min.css'))
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

  def test_event
    before_fixture = Homeostasis::Event.instance_variable_get(:@before_fixture)
    after_fixture = Homeostasis::Event.instance_variable_get(:@after_fixture)
    assert_equal([1,2], before_fixture)
    assert_equal([1,2], after_fixture)
  end

  def test_front
    assert_equal(
     ['_utf8.html.haml',
      'blog/2012-01-01-hello-world.html.md.erb',
      'blog/2012-01-02-second-post.html.md',
      'blog/2099-01-01-future-post.html.md',
      'blog/index.html.haml',
      'index.html.haml',
      'layout.html.haml',
      'multi.html.md.erb',
      'page.html.md'],
     @front.front_site.keys.sort)

    page = @front.front_site['page.html.md']
    assert_equal('/page/', page[:path])
    assert_equal('Page', page[:title])
    
    page_contents = Homeostasis::Helpers.read(dest("page/index.html"))
    assert(page_contents =~ /<title>Page<\/title>/)
    refute(page_contents =~ /:title/)

    index = @front.front_site['index.html.haml']
    assert_equal('/', index[:path])
    assert_equal('Index', index[:title])

    index_contents = Homeostasis::Helpers.read(dest("index.html"))
    assert(index_contents =~ /<title>Index<\/title>/)
    refute(index_contents =~ /:title/)

    hello_world = @front.front_site['blog/2012-01-01-hello-world.html.md.erb']
    assert_equal('/hello-world/', hello_world[:path])
    assert_equal('Hello World', hello_world[:title])
    assert_equal('2012-01-01', hello_world[:date].strftime('%Y-%m-%d'))

    second_post = @front.front_site['blog/2012-01-02-second-post.html.md']
    assert_equal('/second-post/', second_post[:path])
    assert_equal('Second Post', second_post[:title])
    assert_equal('2012-01-02', second_post[:date].strftime('%Y-%m-%d'))
  end

  def test_front_hash
    hash = Homeostasis::FrontHash.from_hash(a: 1, b: 2)
    assert_equal(1, hash['a'])
    assert_equal(1, hash[:a])
    assert(hash.has_key?(:b))
    assert(hash.has_key?('b'))
    refute(hash.has_key?(:c))
    refute(hash.has_key?('c'))
  end

  def test_multi
    refute(File.exists?(dest("multi.html.md")))
    assert(File.exists?(dest("multi/index.html")))

    contents = Homeostasis::Helpers.read(dest("multi/index.html"))
    assert(contents =~ /<h1>Header 1<\/h1>/)
    assert(contents =~ /<title>Multi<\/title>/)
    refute(contents =~ /:title/)
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

    xml = Homeostasis::Helpers.read(dest("sitemap.xml"))
    assert(xml =~ /<loc>http:\/\/local\.fixture\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/page\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/blog\/<\/loc>/)
    assert(xml =~ /<loc>http:\/\/local\.fixture\/hello-world\/<\/loc>/)
    refute(xml =~ /<loc>http:\/\/local\.fixture\/second-post\/<\/loc>/) # private post
    refute(xml =~ /<loc>http:\/\/local\.fixture\/future-post\/<\/loc>/) # future post
    assert_equal(0, xml.scan("<lastmod>").length)
  end

  def test_blog
    assert(Homeostasis::Blog::DATE_REGEX =~ '2012-01-01-title')
    assert_equal('2012-01-01', $1)

    assert(File.exists?(dest("/blog/index.html")))
    assert(File.exists?(dest("/hello-world/index.html")))
    assert(File.exists?(dest("/second-post/index.html")))
    assert(File.exists?(dest("/future-post/index.html")))
    refute(File.exists?(dest("/blog/2012-01-01-hello-world.html")))
    refute(File.exists?(dest("/blog/2012-01-02-second-post.html")))
    refute(File.exists?(dest("/blog/2099-01-01-future-post.html")))

    posts = @blog.blog_posts
    assert_equal(1, posts.length) # doesn't include private posts
    assert_equal('/hello-world/', posts[0][:path])
    assert_equal('2012-01-01', posts[0][:date].strftime('%Y-%m-%d'))
    refute(posts[0].has_key?(:private))

    assert(File.exists?(dest("/rss.xml")))
    rss = Homeostasis::Helpers.read(dest("/rss.xml"))
    assert_match("Sun, 01 Jan 2012 12:00:00 UT", rss)
    assert_match(CGI.escapeHTML('href="http://local.fixture/link/"'), rss)
    assert_match(CGI.escapeHTML('src="http://local.fixture/photo.'), rss)
    assert_match("Hello World", rss)
    assert_match("The Number One: 1", rss)
    refute_match("Second Post", rss)
    refute_match("Future Post", rss)
  end

  private
  def dest(path)
    File.join(@stasis.destination, path)
  end

  def root(path)
    File.join(@stasis.root, path)
  end
end
