require_relative "configuration"

module Plum
  class Engine < ::Rails::Engine
    isolate_namespace Plum
    config.paths["config/routes.rb"] = "config/plum_routes.rb"
    config.paths["db/migrate"] = [ "db/engine_migrate" ]

    initializer "plum.assets" do |app|
      app.config.assets.paths << root.join("app/assets/javascripts")
      app.config.assets.paths << root.join("app/javascript/controllers/plum")
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

    initializer "plum.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/plum_importmap.rb")
      end
    end
  end
end
