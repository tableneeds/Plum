require_relative "plum/version"
require_relative "plum/content_source"
require_relative "plum/configuration"

module Plum
  def self.table_name_prefix
    "plum_"
  end

  def self.register_field_type(**options)
    FieldTypeRegistry.register(**options)
  end
end

require_relative "plum/engine" if defined?(Rails::Engine)
