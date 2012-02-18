require File.join(File.dirname(__FILE__), '..', 'homeostasis')

module Homeostasis
  class Environment
    def initialize(env)
      @env = env
    end

    def method_missing(message, *args, &block)
      if message =~ /\?$/
        @env == message[0..-2]
      else
        super
      end
    end
  end

  ENV = Environment.new(::ENV['HOMEOSTASIS_ENV'] || 'development')
end
