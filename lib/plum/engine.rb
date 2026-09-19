require_relative "configuration"
require_relative "static_cache"
require_relative "static_cache/middleware"

module Plum
  class Engine < ::Rails::Engine
    isolate_namespace Plum
    config.paths["config/routes.rb"] = "config/plum_routes.rb"
    config.paths["db/migrate"] = [ "db/engine_migrate" ]

    initializer "plum.static_cache" do |app|
      # Always installed; it no-ops per request unless StaticCache.enabled?
      app.middleware.use Plum::StaticCache::Middleware
    end

    initializer "plum.assets" do |app|
      app.config.assets.paths << root.join("app/assets/javascripts")
      # Importmap exposes these files as `plum/*`, so Propshaft must resolve
      # them relative to the parent controllers directory.
      app.config.assets.paths << root.join("app/javascript/controllers")
      app.config.assets.paths << root.join("vendor/javascript")

      lexxy_spec = Gem.loaded_specs["lexxy"]
      if lexxy_spec
        lexxy_root = Pathname.new(lexxy_spec.gem_dir)
        %w[app/assets/stylesheets app/javascript].each do |subpath|
          path = lexxy_root.join(subpath)
          app.config.assets.paths << path.to_s if path.exist?
        end
      end
    end

    # Build a Plum-scoped importmap instead of merging Plum's pins into the
    # host app's global importmap. Plum's layouts render this map (host JS stack
    # + Plum's additions), while the host app's own pages keep a clean importmap
    # free of Plum's controllers/lexxy/activestorage pins. Runs after the host's
    # importmap is configured so we can copy its paths.
    initializer "plum.importmap", after: "importmap" do |app|
      next unless defined?(Importmap::Map) && app.config.respond_to?(:importmap)

      Plum.importmap = Importmap::Map.new
      Array(app.config.importmap.paths).each { |path| Plum.importmap.draw(path) }
      Plum.importmap.draw(root.join("config/plum_importmap.rb"))
    end
  end
end
