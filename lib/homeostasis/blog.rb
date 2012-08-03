require File.join(File.dirname(__FILE__), '..', 'homeostasis')
require 'date'

class Homeostasis::Blog < Stasis::Plugin
  before_all    :before_all
  after_all     :after_all
  action_method :blog_posts

  def initialize(stasis)
    @stasis = stasis
    @@directory = nil
    @@posts = []
  end

  def self.directory(directory)
    @@directory = directory
  end

  def before_all
    raise 'Homeostasis::Blog#directory never set' if @@directory.nil?
    blog_dir = File.join(@stasis.root, @@directory)
    front_site = Homeostasis::Front._front_site
    Dir.glob("#{blog_dir}/*").each do |filename|
      next if File.basename(filename) !~ /^(\d{4}-\d{2}-\d{2})-/
      date = $1
      post = front_site[filename.sub(@stasis.root, '')[1..-1]] || {}
      post[:date] = Date.parse(date)
      post[:path] = post[:path].sub("/#{@@directory}/#{$1}-", "/#{@@directory}/")
      @@posts << post
    end
    @@posts = @@posts.sort_by {|post| post[:date]}.reverse
  end

  def after_all
    return if @@directory.nil?
    blog_dir = File.join(@stasis.destination, @@directory)
    Dir.glob("#{blog_dir}/*").each do |filename|
      next if filename !~ /^\d{4}-\d{2}-\d{2}-/
      newbase = File.basename(filename).sub(/^(\d{4}-\d{2}-\d{2})-/, '')
      FileUtils.mv(filename, File.join(File.dirname(filename), newbase))
    end
  end

  def blog_posts
    raise 'Homeostasis::Blog#directory never set' if @@directory.nil?
    @@posts
  end
end

Stasis.register(Homeostasis::Blog)
