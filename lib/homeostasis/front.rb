require File.join(File.dirname(__FILE__), '..', 'homeostasis')
require 'yaml'

class Homeostasis::Front < Stasis::Plugin
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
      contents = File.read(path)
      next if contents !~ @@matchers[File.extname(path)[1..-1]]

      lines, data, index = contents.split("\n"), "", 1
      while index < lines.size
        break if lines[index] !~ /^  /
        data += lines[index] + "\n"
        index += 1
      end

      relative = path[(@stasis.root.length+1)..-1]
      ext = Tilt.mappings.keys.find { |ext| File.extname(path)[1..-1] == ext }
      dest = (ext && File.extname(relative) == ".#{ext}") ?
        relative[0..-1*ext.length-2] :
        relative
      dest = trailify(dest)
      
      begin
        yaml = YAML.load(data)
        yaml[:path] = dest
        @@front_site[front_key(path)] = yaml if yaml.is_a?(Hash)
      rescue Psych::SyntaxError => error
        @@front_site[front_key(path)] = {:path => dest}
      end
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

  def self.matchers
    @@matchers
  end

  def self.matchers=(ext)
    @@matchers = ext
  end

  private
  def front_key(filename)
    filename.sub(@stasis.root, '')[1..-1]
  end

  def trailify(filename)
    @trail_included ||= @stasis.plugins.any? {|plugin| plugin.is_a?(Homeostasis::Trail)}
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

Stasis.register(Homeostasis::Front)
