require_relative "plum/version"
require_relative "plum/content_source"
require_relative "plum/configuration"

module Plum
  def self.table_name_prefix
    "plum_"
  end
end

require_relative "plum/engine" if defined?(Rails::Engine)
