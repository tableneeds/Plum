require_relative "configuration"

module Plum
  class Engine < ::Rails::Engine
    isolate_namespace Plum
    config.paths["config/routes.rb"] = "config/plum_routes.rb"
    config.paths["db/migrate"] = []

    initializer "plum.assets" do |app|
      if defined?(Lexxy::Engine)
        lexxy_stylesheets = Lexxy::Engine.root.join("app/assets/stylesheets")
        app.config.assets.paths << lexxy_stylesheets.to_s if lexxy_stylesheets.exist?
      end
    end
  end
end
