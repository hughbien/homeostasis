require File.join(File.dirname(__FILE__), 'env')
require 'fileutils'

class Homeostasis::Trail < Stasis::Plugin
  after_all :after_all

  def initialize(stasis)
    @stasis = stasis
  end

  def after_all
    Dir.glob("#{@stasis.destination}/**/*.html").each do |filename|
      next if File.basename(filename) == 'index.html'
      dir = "#{filename[0..-6]}/"
      if File.exists?("#{dir}index.html")
        puts "Unable to trail #{filename[(@stasis.destination.length+1)..-1]}"
      else
        FileUtils.mkdir_p(dir)
        File.rename(filename, "#{dir}index.html")
      end
    end
  end
end

Stasis.register(Homeostasis::Trail)
