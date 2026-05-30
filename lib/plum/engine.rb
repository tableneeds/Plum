require_relative "configuration"

module Plum
  class Engine < ::Rails::Engine
    isolate_namespace Plum
    config.paths["config/routes.rb"] = "config/plum_routes.rb"
    config.paths["db/migrate"] = []
  end
end
