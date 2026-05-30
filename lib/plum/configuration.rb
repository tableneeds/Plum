require_relative "content_source_registry"

module Plum
  class Configuration
    attr_accessor :authorize_with, :current_site_resolver, :current_user_resolver
    attr_writer :theme_paths
    attr_reader :content_sources

    def initialize
      @authorize_with = :plum
      @content_sources = ContentSourceRegistry.new
      @current_site_resolver = ->(_controller) { Plum::Site.first_or_create_standalone! }
      @current_user_resolver = lambda { |controller|
        Plum::User.find_by(id: controller.session[:plum_user_id]) if controller.session[:plum_user_id]
      }
    end

    def theme_paths
      Array(@theme_paths.presence || default_theme_paths).map { |path| Pathname(path) }.uniq(&:to_s)
    end

    def register_content_source(handle, source = nil, &block)
      content_sources.register(handle, source, &block)
    end

    private

    def default_theme_paths
      paths = []
      paths << Rails.root.join("app/themes") if defined?(Rails) && Rails.root
      paths << Plum::Engine.root.join("app/themes") if defined?(Plum::Engine)
      paths
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

  def self.register_content_source(handle, source = nil, &block)
    configuration.register_content_source(handle, source, &block)
  end

  def self.content_sources_for(controller, site:)
    configuration.content_sources.to_liquid_context(controller: controller, site: site)
  end
end
