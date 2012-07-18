require File.join(File.dirname(__FILE__), '..', 'homeostasis')
require 'yaml'

class Homeostasis::Front < Stasis::Plugin
  before_all    :before_all
  action_method :front
  action_method :front_site

  def initialize(stasis)
    @stasis = stasis
    @front_site = {}
  end

  def before_all
    @stasis.paths.each do |path|
      next if ignore?(path) || path !~ /\.haml$/
      contents = File.read(path)
      next if contents !~ /^-#/

      lines, data, index = contents.split("\n"), "", 1
      while index < lines.size
        break if lines[index] !~ /^  /
        data += lines[index] + "\n"
        index += 1
      end
      
      begin
        @front_site[front_key(path)] = YAML.load(data)
      rescue Psych::SyntaxError => error
        puts "#{path}: #{error.message}"
      end
    end
  end

  def front
    @front_site[front_key(@stasis.path)] || {}
  end

  def front_site
    @front_site
  end

  private
  # TODO: extract, in common with asset plugin
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

  def front_key(filename)
    File.basename(filename).sub(/\.haml$/, '').sub(/\.html$/, '').to_sym
  end
end

Stasis.register(Homeostasis::Front)
