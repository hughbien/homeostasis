require File.join(File.dirname(__FILE__), '..', 'homeostasis')
require 'digest/sha1'

class Homeostasis::Asset < Stasis::Plugin
  before_all :before_all
  after_all  :after_all

  def initialize(stasis)
    @stasis = stasis
    @@matcher = /\.(jpg|png|gif|css|js)/i
    @@mapping = {}
    @@concats = {}
    @@concats_pre = {}
  end

  def before_all
    @stasis.paths.each do |path|
      next if ignore?(path)
      relative = path[(@stasis.root.length+1)..-1]
      ext = Tilt.mappings.keys.find { |ext| File.extname(path)[1..-1] == ext }
      dest = (ext && File.extname(relative) == ".#{ext}") ?
        relative[0..-1*ext.length-2] :
        relative
      @@mapping[relative] = dest
    end
    imapping = @@mapping.invert
    @@concats_pre.each do |dest, files|
      full_origs = files.map do |file|
        orig = imapping[file]
        raise "Asset not found #{file}" if orig.nil?
        File.join(@stasis.root, imapping[file])
      end
      @@concats[dest] = full_origs
    end
  end

  def after_all
    asset_paths = {}
    @@concats.each do |concatted, files|
      version = self.class.version(files)
      full_concatted = File.join(@stasis.destination, concatted)
      full_concatted = self.class.stamped(full_concatted, version)
      content = files.map do |full_orig|
        orig = full_orig[(@stasis.root.length+1)..-1]
        full_dest = File.join(@stasis.destination, @@mapping[orig])
        raise "File not found #{full_dest}" if !File.exists?(full_dest)
        file_contents = File.read(full_dest)
        @@mapping.delete(orig)
        File.delete(full_dest)
        file_contents
      end.join("\n")
      File.open(full_concatted, 'w') {|f| f.print(content)}
      asset_paths[concatted] = full_concatted[(@stasis.destination.length+1)..-1]
    end
    @@mapping.each do |orig, dest|
      next if dest !~ @@matcher
      full_orig = File.join(@stasis.root, orig)
      full_dest = File.join(@stasis.destination, dest)
      versioned = self.class.stamped(full_dest, self.class.version(full_orig))
      File.rename(full_dest, versioned)

      relative_dest = full_dest[(@stasis.destination.length+1)..-1]
      relative_versioned = versioned[(@stasis.destination.length+1)..-1]
      asset_paths[relative_dest] = relative_versioned
    end
    (@@mapping.values + asset_paths.values).each do |dest|
      filename = File.join(@stasis.destination, dest)
      next if !File.exist?(filename)
      contents = File.read(filename)
      begin
        asset_paths.each do |old, new|
          contents.gsub!(/([^a-zA-Z0-9.-_])#{Regexp.escape(old)}/, "\\1#{new}")
        end
        File.open(filename, 'w') {|f| f.print(contents)}
      rescue ArgumentError
        next
      end
    end
  end

  def self.stamped(path, version)
    path = path.split('.')
    path.insert(
      path.length > 1 ? -2 : -1,
      version)
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

  def self.matcher=(regex)
    @@matcher = regex
  end

  def self.mapping
    @@mapping
  end

  def self.concat(dest, files)
    @@concats_pre[dest] = files
  end

  def self.concats
    @@concats
  end

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
end

Stasis.register(Homeostasis::Asset)
