require_relative "configuration"

module Plum
  class Engine < ::Rails::Engine
    isolate_namespace Plum
    config.paths["config/routes.rb"] = "config/plum_routes.rb"
    config.paths["db/migrate"] = []

    initializer "plum.assets" do |app|
      lexxy_spec = Gem.loaded_specs["lexxy"]
      if lexxy_spec
        lexxy_root = Pathname.new(lexxy_spec.gem_dir)
        %w[app/assets/stylesheets app/javascript].each do |subpath|
          path = lexxy_root.join(subpath)
          app.config.assets.paths << path.to_s if path.exist?
        end
      end
    end
  end
end
