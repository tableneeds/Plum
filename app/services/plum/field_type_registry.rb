module Plum
  class FieldTypeRegistry
    Definition = Struct.new(
      :handle, :label, :configuration, :partial, :normalizer, :validator, :expander,
      keyword_init: true
    )

    COMMON_CONFIGURATION = %w[label instructions required default placeholder].freeze
    NESTED_FIELD_TYPES = %w[text textarea number boolean date url].freeze

    DEFINITIONS = [
      Definition.new(handle: "text", label: "Text", configuration: []),
      Definition.new(handle: "textarea", label: "Textarea", configuration: []),
      Definition.new(handle: "rich_text", label: "Rich Text", configuration: []),
      Definition.new(handle: "number", label: "Number", configuration: %w[number_kind min max step unit]),
      Definition.new(handle: "boolean", label: "Boolean", configuration: []),
      Definition.new(handle: "date", label: "Date / Time", configuration: %w[date_mode min max]),
      Definition.new(handle: "select", label: "Select", configuration: %w[options]),
      Definition.new(handle: "radio", label: "Radio", configuration: %w[options]),
      Definition.new(handle: "button_group", label: "Button Group", configuration: %w[options]),
      Definition.new(handle: "checkboxes", label: "Checkboxes", configuration: %w[options]),
      Definition.new(handle: "color", label: "Color", configuration: []),
      Definition.new(handle: "url", label: "URL", configuration: []),
      Definition.new(handle: "taxonomy", label: "Taxonomy", configuration: %w[taxonomy]),
      Definition.new(handle: "image", label: "Image", configuration: []),
      Definition.new(handle: "images", label: "Images", configuration: %w[min_items max_items]),
      Definition.new(handle: "relationship", label: "Relationship", configuration: %w[content_type multiple min_items max_items]),
      Definition.new(handle: "blocks", label: "Blocks", configuration: %w[blocks]),
      Definition.new(handle: "list", label: "List", configuration: %w[min_items max_items unique]),
      Definition.new(handle: "group", label: "Group", configuration: %w[fields]),
      Definition.new(handle: "repeater", label: "Repeater", configuration: %w[fields min_items max_items]),
      Definition.new(handle: "section", label: "Section", configuration: [])
    ].freeze

    class << self
      def all
        DEFINITIONS + custom_definitions.values
      end

      def handles
        all.map(&:handle)
      end

      def find(handle)
        all.find { |definition| definition.handle == handle.to_s }
      end

      def include?(handle)
        find(handle).present?
      end

      def options
        all.map { |definition| [ definition.label, definition.handle ] }
      end

      def as_json
        all.map { |definition| { handle: definition.handle, label: definition.label } }
      end

      def register(handle:, label:, configuration: [], partial: nil, normalizer: nil, validator: nil, expander: nil)
        normalized_handle = handle.to_s
        raise ArgumentError, "Field type handle is invalid" unless normalized_handle.match?(/\A[a-z][a-z0-9_]*\z/)
        raise ArgumentError, "Field type #{normalized_handle} is already registered" if include?(normalized_handle)
        raise ArgumentError, "Custom field types require an editor partial" if partial.blank?

        custom_definitions[normalized_handle] = Definition.new(
          handle: normalized_handle,
          label: label.to_s.presence || normalized_handle.titleize,
          configuration: Array(configuration).map(&:to_s),
          partial: partial.to_s,
          normalizer: normalizer,
          validator: validator,
          expander: expander
        ).freeze
      end

      def reset_custom!
        @custom_definitions = {}
      end

      private

      def custom_definitions
        @custom_definitions ||= {}
      end
    end
  end
end
