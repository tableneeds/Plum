require_relative "plum/version"
require_relative "plum/content_source"
require_relative "plum/configuration"

module Plum
  class << self
    # A Plum-scoped importmap (host pins + Plum's own pins), used only by Plum's
    # layouts. Keeps Plum's controllers/lexxy/activestorage out of the host
    # app's global importmap so a mounted Plum can't pollute the host's JS.
    attr_accessor :importmap
  end

  def self.table_name_prefix
    "plum_"
  end

  def self.register_field_type(**options)
    FieldTypeRegistry.register(**options)
  end
end

require_relative "plum/engine" if defined?(Rails::Engine)
