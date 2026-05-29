require_relative "content_source_registry"

module Plum
  class Configuration
    attr_accessor :authorize_with, :current_site_resolver, :current_user_resolver
    attr_reader :content_sources

    def initialize
      @authorize_with = :plum
      @content_sources = ContentSourceRegistry.new
      @current_site_resolver = ->(_controller) { Plum::Site.first_or_create_standalone! }
      @current_user_resolver = lambda { |controller|
        Plum::User.find_by(id: controller.session[:plum_user_id]) if controller.session[:plum_user_id]
      }
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.current_site(controller)
    configuration.current_site_resolver.call(controller)
  end

  def self.current_user(controller)
    configuration.current_user_resolver.call(controller)
  end

  def self.content_sources_for(controller)
    configuration.content_sources.to_liquid_context(controller)
  end
end
