module Plum
  class ThemeSettingsParams
    def initialize(theme)
      @theme = theme
    end

    def normalize(raw_settings)
      raw_settings = raw_settings.to_h.stringify_keys

      theme.settings_fields.each_with_object({}) do |field, settings|
        handle = field["handle"].to_s
        next if handle.blank?

        value = raw_settings.key?(handle) ? raw_settings[handle] : field["default"]
        settings[handle] = normalize_value(field, value)
      end
    end

    private

    attr_reader :theme

    def normalize_value(field, value)
      case field["type"].to_s
      when "boolean"
        value.nil? ? false : ActiveModel::Type::Boolean.new.cast(value)
      when "select"
        normalize_select_value(field, value)
      else
        value.to_s
      end
    end

    def normalize_select_value(field, value)
      values = select_option_values(field)
      normalized_value = value.to_s

      return normalized_value if values.blank? || values.include?(normalized_value)

      default_value = field["default"].to_s
      values.include?(default_value) ? default_value : values.first
    end

    def select_option_values(field)
      Array(field["options"]).filter_map do |option|
        if option.is_a?(Hash)
          option.stringify_keys["value"].to_s.presence
        else
          option.to_s.presence
        end
      end
    end
  end
end
