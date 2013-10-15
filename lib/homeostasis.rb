require 'rubygems'
require 'stasis'
require 'digest/sha1'
require 'yaml'
require 'cgi'
require 'uri'
require 'tilt'
require 'tempfile'
require 'preamble'

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
      CGI::escapeHTML(html.to_s)
    end

    def render_multi(path, body = nil, context = nil, locals = {})
      body ||= Helpers.read(path)
      render_templates_for(path).each do |template|
        blk = proc { body }
        body = template.new(path, &blk).render(context, locals)
      end
      body
    end

    def render_templates_for(path)
      File.basename(path).split('.')[1..-1].reverse.map { |ext| Tilt[ext] }.compact
    end

    def self.read(path)
      File.read(path, encoding: 'UTF-8')
    end

    def self.stasis_path
      @@stasis_path
    rescue NameError
      nil
    end

    def self.set_stasis_path(stasis, path)
      @@stasis_path = path if path =~ /^#{stasis.root}/ || path.nil?
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
          contents = Helpers.read(full_dest)
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
        contents = Helpers.read(file)
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

  class Event < Stasis::Plugin
    before_all :before_all_send
    after_all :after_all_send
    controller_method :before_all
    controller_method :after_all
    reset :reset

    def initialize(stasis)
      @stasis = stasis
      reset
    end

    def before_all(&block)
      @befores << block
    end

    def after_all(&block)
      @afters << block
    end

    def before_all_send
      @befores.each { |b| @stasis.action.instance_eval(&b) }
    end

    def after_all_send
      @afters.each { |b| @stasis.action.instance_eval(&b) }
    end

    def reset
      @befores = []
      @afters = []
    end
  end

  class Front < Stasis::Plugin
    include Helpers
    before_all    :before_all
    before_render :before_render
    after_render  :after_render
    action_method :front
    action_method :front_site
    priority      2

    def initialize(stasis)
      @stasis = stasis
      @@front_site = {}
      @@matcher = /\.erb|\.haml|\.html|\.md$/
    end

    def before_all
      @stasis.paths.each do |path|
        yaml, body = Front.preamble_load(path)
        next if yaml.nil?

        # add special :path key for generated files
        if !ignore?(path)
          relative = path[(@stasis.root.length+1)..-1]
          ext = Tilt.mappings.keys.find { |ext| File.extname(path)[1..-1] == ext }
          dest = (ext && File.extname(relative) == ".#{ext}") ?
            relative[0..-1*ext.length-2] :
            relative
          yaml[:path] = trailify(Multi.drop_tilt_exts(dest))
        end
        @@front_site[front_key(path)] = yaml
      end
    end

    def before_render
      if @stasis.path && @stasis.path =~ @@matcher && !ignore?(@stasis.path)
        ext = File.basename(@stasis.path).split('.', 2).last
        yaml, body = Front.preamble_load(@stasis.path)
        @tmpfile = Tempfile.new(['temp', ".#{ext}"])
        @tmpfile.puts(body)
        @tmpfile.close
        Helpers.set_stasis_path(@stasis, @stasis.path)
        @stasis.path = @tmpfile.path
      end
    end

    def after_render
      if @tmpfile
        @stasis.path = Helpers.stasis_path if @stasis.path !~ /^#{@stasis.root}/
        Helpers.set_stasis_path(@stasis, nil)
        @tmpfile.unlink
        @tmpfile = nil
      end
    end

    def front
      @@front_site[front_key(Helpers.stasis_path || @stasis.path)] || {}
    end

    def front_site
      @@front_site
    end

    def self._front_site # for other plugins
      @@front_site
    end

    def self._front_key(stasis, filename) # for other plugins
      filename.sub(stasis.root, '')[1..-1]
    end

    def self.config(options)
      @@matcher = options[:matcher] if options[:matcher]
    end

    def self.preamble_load(path)
      return nil if path.nil? || path !~ @@matcher
      Preamble.load(path)
    rescue
      [{}, Helpers.read(path)]
    end

    private
    def front_key(filename)
      self.class._front_key(@stasis, filename)
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

  class Multi < Stasis::Plugin
    include Helpers
    before_render :before_render
    after_render  :after_render
    after_write   :after_write
    priority      1

    def initialize(stasis)
      @stasis = stasis
    end

    def before_render
      if @stasis.path && !ignore?(@stasis.path)
        exts = File.basename(@stasis.path).split('.')[2..-1]
        return if exts.nil? || exts.length < 2

        yaml, body = Front.preamble_load(@stasis.path)
        body ||= Helpers.read(@stasis.path)

        @tmpfile = Tempfile.new(["temp", ".txt"])
        @tmpfile.puts(render_multi(@stasis.path, body, @stasis.action))
        @tmpfile.close
        Helpers.set_stasis_path(@stasis, @stasis.path)
        puts "Multi: #{@stasis.path} => #{@tmpfile.path}"
        @stasis.path = @tmpfile.path
      end
    end

    def after_render
      if @tmpfile
        @stasis.path = Helpers.stasis_path if @stasis.path !~ /^#{@stasis.root}/
        Helpers.set_stasis_path(@stasis, nil)
        @tmpfile.unlink if @tmpfile
        @tmpfile = nil
      end
    end

    def after_write
      return if @stasis.path.nil? || ignore?(@stasis.path)
      dest = self.class.drop_tilt_exts(@stasis.dest)
      File.rename(@stasis.dest, dest) if dest != @stasis.dest
    end

    def self.drop_tilt_exts(path)
      dirname = File.dirname(path)
      basename = File.basename(path)
      exts = basename.split('.')[2..-1]
      return path if exts.nil? || exts.length < 1

      exts.each do |ext|
        basename = basename.sub(/\.#{ext}/, '')
      end
      File.join(dirname, basename)
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
    before_render :before_render
    after_all     :after_all
    action_method :blog_posts
    priority      3

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
        post[:blog] = true
        post[:date] = Date.parse(date)
        post[:path] = post[:path].sub(
          "/#{@@directory}/#{date}-",
          File.join('/', @@path, '/'))
        @@posts << post
      end
      @@posts = @@posts.sort_by { |post| post[:date] }.reverse
    end

    def before_render
      path = Helpers.stasis_path || @stasis.path
      return if path.nil?

      post = Homeostasis::Front._front_site[Homeostasis::Front._front_key(@stasis, path)]
      if post && post[:blog] && post[:date] && post[:path]
        yaml, body = Front.preamble_load(path)
        post[:body] = render_multi(path, body, @stasis.action)
      end
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
      blog_posts.reject {|p| p.has_key?(:norss) }[0..5].each do |post|
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
  Stasis.register(Homeostasis::Event)
  Stasis.register(Homeostasis::Front)
  Stasis.register(Homeostasis::Multi)
  Stasis.register(Homeostasis::Trail)
  Stasis.register(Homeostasis::Sitemap)
  Stasis.register(Homeostasis::Blog)
end
