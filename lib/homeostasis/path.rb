require File.join(File.dirname(__FILE__), 'env')

class Homeostasis::Path < Stasis::Plugin
  action_method :path

  def initialize(stasis)
    @stasis = stasis
  end

  def path(uri)
    uri = uri[0..-2] if uri =~ /\/$/
    Homeostasis::ENV.development? ?
      "#{uri}.html" :
      "#{uri}/"
  end
end

Stasis.register(Homeostasis::Path)