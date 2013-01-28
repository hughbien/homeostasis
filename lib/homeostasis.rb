require 'rubygems'
require 'stasis'
require 'digest/sha1'
require 'bluecloth'
require 'yaml'
require 'cgi'
require 'uri'

module Homeostasis
  module Helpers
    private
    def ignore?(path)
      @ignore_paths ||= @stasis.plugins.
        find { |plugin| plugin.class == Stasis::Ignore }.
        instance_variable_get(:@ignore)

      matches = _match_key?(@ignore_paths, path)
      matches.each do |group|
        group.each do |group_path|
          return true if _within?(group_path)
        end
      end
      false
    end

    def h(html)
      CGI::escapeHTML(html)
    end
  end

  class Asset < Stasis::Plugin
    include Helpers
    before_all :before_all
    after_all  :after_all

    def initialize(stasis)
      @stasis = stasis
      @@matcher = /\.(jpg|png|gif|css|js)/i
      @@replace_matcher = /\.(html|css|js)/i
      @@mapping = {}
      @@concats = {}
      @@orig_concats = {}
    end

    def before_all
      # build mapping of relative filenames => destination
      @stasis.paths.each do |path|
        next if ignore?(path)
        relative = path[(@stasis.root.length+1)..-1]
        ext = Tilt.mappings.keys.find { |ext| File.extname(path)[1..-1] == ext }
        dest = (ext && File.extname(relative) == ".#{ext}") ?
          relative[0..-1*ext.length-2] :
          relative
        @@mapping[relative] = dest
      end

      # build orig_concats of destination => [original filenames,]
      inverted = @@mapping.invert
      @@concats.each do |dest, files|
        @@orig_concats[dest] = files.map do |file|
          raise "Asset not found #{file}" if !inverted.has_key?(file)
          File.join(@stasis.root, inverted[file])
        end
      end
    end

    def after_all
      assets = {}
      strip_dest = (@stasis.destination.length + 1)..-1

      # concatenate files with stamps
      @@orig_concats.each do |concatted, files|
        full_concatted = self.class.stamped(
          File.join(@stasis.destination, concatted),
          self.class.version(files))
        content = files.map do |full_orig|
          orig = full_orig[(@stasis.root.length+1)..-1]
          full_dest = File.join(@stasis.destination, @@mapping[orig])
          raise "File not found #{full_dest}" if !File.exists?(full_dest)
          contents = File.read(full_dest)
          @@mapping.delete(orig)
          File.delete(full_dest)
          contents
        end.join("\n")
        File.open(full_concatted, 'w') { |f| f.print(content) }
        assets[concatted] = full_concatted[strip_dest]
      end

      # stamp files that don't require concatentation
      @@mapping.each do |orig, dest|
        next if dest !~ @@matcher
        full_orig = File.join(@stasis.root, orig)
        full_dest = File.join(@stasis.destination, dest)
        versioned = self.class.stamped(full_dest, self.class.version(full_orig))
        File.rename(full_dest, versioned)
        assets[full_dest[strip_dest]] = versioned[strip_dest]
      end

      # read contents of each file, search/replace assets with stamps
      front_site = Homeostasis::Front._front_site
      inverted = @@mapping.invert
      Dir.glob("#{@stasis.destination}/**/*").each do |file|
        next if file !~ @@replace_matcher || File.directory?(file)
        contents = File.read(file)
        front = front_site[inverted[file.sub("#{@stasis.destination}/", "")]]
        assets.each do |old, new|
          old = Regexp.escape(old)
          contents.gsub!(/([^a-zA-Z0-9\.\-_])#{old}/, "\\1#{new}")
          contents.gsub!(/^#{old}/, new)
          if front && front[:body] # for RSS feed
            front[:body].gsub!(/([^a-zA-Z0-9\.\-_])#{old}/, "\\1#{new}")
            front[:body].gsub!(/^#{old}/, new)
          end
        end
        File.open(file, 'w') { |f| f.print(contents) }
      end
    end

    def self.stamped(path, version)
      path = path.split('.')
      path.insert(path.length > 1 ? -2 : -1, version)
      path.join('.')
    end

    def self.version(paths)
      paths = [paths] if !paths.is_a?(Array)
      versions = paths.map do |path|
        log = `git log -n1 #{path} 2> /dev/null`.split("\n")
        log.length > 1 ? log[0].split(' ').last : '0'
      end
      versions.size == 1 ?
        versions[0] :
        Digest::SHA1.hexdigest(versions.join('.'))
    end

    def self.config(options)
      @@matcher = options[:matcher] if options[:matcher]
      @@replace_matcher = options[:replace_matcher] if options[:replace_matcher]
    end

    def self.concat(dest, files)
      @@concats[dest] = files
    end

    private
  end

  class Front < Stasis::Plugin
    include Helpers
    before_all    :before_all
    action_method :front
    action_method :front_site

    def initialize(stasis)
      @stasis = stasis
      @@front_site = {}
      @@matchers = {
        'erb'  => /<%#/,
        'haml' => /-#/,
        'html' => /<!--/,
        'md'   => /<!--/
      }
    end

    def before_all
      @stasis.paths.each do |path|
        next if path !~ /\.(#{@@matchers.keys.join('|')})$/
        if (contents = File.read(path)) !~ @@matchers[File.extname(path)[1..-1]]
          yaml = {}
        else
          lines, data, index = contents.split("\n"), "", 1
          while index < lines.size
            break if lines[index] !~ /^  /
            data += lines[index] + "\n"
            index += 1
          end
          begin
            yaml = YAML.load(data)
          rescue Psych::SyntaxError
            yaml = {}
          end
        end

        # add special :path key for generated files
        if !ignore?(path)
          relative = path[(@stasis.root.length+1)..-1]
          ext = Tilt.mappings.keys.find { |ext| File.extname(path)[1..-1] == ext }
          dest = trailify((ext && File.extname(relative) == ".#{ext}") ?
            relative[0..-1*ext.length-2] :
            relative)
          yaml[:path] = dest
        end
        @@front_site[front_key(path)] = yaml
      end
    end

    def front
      @@front_site[front_key(@stasis.path)] || {}
    end

    def front_site
      @@front_site
    end

    def self._front_site # for other plugins
      @@front_site
    end

    def self.config(options)
      @@matchers = options[:matchers] if options[:matchers]
    end

    private
    def front_key(filename)
      filename.sub(@stasis.root, '')[1..-1]
    end

    def trailify(filename)
      @trail_included ||= @stasis.plugins.any? { |plugin| plugin.is_a?(Homeostasis::Trail) }
      if filename == 'index.html'
        '/'
      elsif File.basename(filename) == 'index.html'
        "/#{File.dirname(filename)}/"
      elsif @trail_included
        "/#{filename.sub(/\.html$/, '/')}"
      else
        "/#{filename}"
      end
    end
  end

  class Trail < Stasis::Plugin
    after_all :after_all

    def initialize(stasis)
      @stasis = stasis
    end

    def after_all
      dest = @stasis.destination
      Dir.glob("#{dest}/**/*.html").each do |filename|
        next if filename =~ /\/index\.html$/
        dir = "#{filename.sub(/\.html$/, '')}/"
        FileUtils.mkdir_p(dir)
        File.rename(filename, "#{dir}index.html")
      end
    end
  end

  class Sitemap < Stasis::Plugin
    include Helpers
    after_all :after_all

    def initialize(stasis)
      @stasis = stasis
      @@url = nil
    end

    def self.config(options)
      @@url = options[:url]
      @@lastmod = options[:lastmod] || false
    end
    
    def after_all
      return if @@url.nil?
      xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      xml += "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
      front_site = Homeostasis::Front._front_site
      pages = front_site.keys.sort_by do |page|
        depth = page.scan('/').length
        depth -= 1 if page =~ /index\.html/
        "#{depth}-#{page}"
      end
      pages.each do |page|
        front = front_site[page]
        filename = File.join(@stasis.root, page)
        next if page !~ /\.html/ || !front || front[:private] || front[:path].nil?

        log = `git log -n1 #{filename} 2> /dev/null | grep "Date:"`
        lastmod = log.length > 0 ?
          Date.parse(log.split("\n")[0].split(":",2)[1].strip).strftime('%Y-%m-%d') :
          nil
        xml += "  <url>\n"
        xml += "    <loc>#{h(@@url + front[:path])}</loc>\n" if front[:path]
        xml += "    <lastmod>#{h lastmod}</lastmod>\n" if @@lastmod && lastmod
        xml += "    <changefreq>#{h front[:changefreq]}</changefreq>\n" if front[:changefreq]
        xml += "    <priority>#{h front[:priority]}</priority>\n" if front[:priority]
        xml += "  </url>\n"
      end
      xml += '</urlset>'
      File.open(File.join(@stasis.destination, 'sitemap.xml'), 'w') do |f|
        f.puts(xml)
      end
    end
  end

  class Blog < Stasis::Plugin
    include Helpers
    DATE_REGEX = /^(\d{4}-\d{2}-\d{2})-/
    before_all    :before_all
    after_all     :after_all
    action_method :blog_posts

    def initialize(stasis)
      @stasis = stasis
      @@directory = nil
      @@path = nil
      @@url = nil
      @@title = nil
      @@desc = nil
      @@posts = []
    end

    def self.config(options)
      @@directory = options[:directory]
      @@path = options[:path] || options[:directory]
      @@url = options[:url]
      @@title = options[:title]
      @@desc = options[:desc]
    end

    def before_all
      return if @@directory.nil?
      @@posts = []
      front_site = Homeostasis::Front._front_site
      Dir.glob("#{File.join(@stasis.root, @@directory)}/*").each do |filename|
        next if File.basename(filename) !~ DATE_REGEX
        date = $1
        post = front_site[filename.sub(@stasis.root, '')[1..-1]] || {}
        post[:date] = Date.parse(date)
        post[:path] = post[:path].sub(
          "/#{@@directory}/#{date}-",
          File.join('/', @@path, '/'))
        post[:body] = BlueCloth.new(File.read(filename)).to_html if filename =~ /\.md$/
        @@posts << post
      end
      @@posts = @@posts.sort_by { |post| post[:date] }.reverse
    end

    def after_all
      return if @@directory.nil?
      blog_dest = File.join(@stasis.destination, @@path)
      FileUtils.mkdir_p(blog_dest) if !Dir.exist?(blog_dest)
      Dir.glob("#{File.join(@stasis.destination, @@directory)}/*").each do |filename|
        next if (base = File.basename(filename)) !~ DATE_REGEX
        FileUtils.mv(filename, File.join(blog_dest, base.sub(DATE_REGEX, '')))
      end
      url = h(File.join(@@url, @@path))
      zone = Time.new.zone
      rss = "<?xml version=\"1.0\"?>\n"
      rss += "<rss version=\"2.0\">\n"
      rss += "  <channel>\n"
      rss += "    <title>#{h @@title}</title>\n" if @@title
      rss += "    <link>#{h @@url}/</link>\n" if @@url
      rss += "    <description>#{h @@desc}</description>\n" if @@desc
      blog_posts[0..5].each do |post|
        body = post[:body]
        body.gsub!(/(href|src)=('|")\//, "\\1=\\2#{@@url}/")
        rss += "    <item>\n"
        rss += "      <title>#{h post[:title]}</title>\n"
        rss += "      <link>#{h(File.join(@@url, post[:path]))}</link>\n"
        rss += "      <pubDate>#{post[:date].strftime("%a, %d %b %Y 0:00:01 #{zone}")}</pubDate>\n"
        rss += "      <description>#{h post[:body]}</description>\n"
        rss += "    </item>\n"
      end
      rss += "  </channel>\n"
      rss += "</rss>"
      File.open(File.join(blog_dest, 'rss.xml'), 'w') do |f|
        f.puts(rss)
      end
    end

    def blog_posts
      raise 'Homeostasis::Blog#config never called' if @@directory.nil?
      @@posts
    end
  end
end

if !ENV['HOMEOSTASIS_UNREGISTER']
  Stasis.register(Homeostasis::Asset)
  Stasis.register(Homeostasis::Front)
  Stasis.register(Homeostasis::Trail)
  Stasis.register(Homeostasis::Sitemap)
  Stasis.register(Homeostasis::Blog)
end
