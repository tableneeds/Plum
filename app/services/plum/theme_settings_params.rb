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

        settings[handle] = normalize_value(field, raw_settings[handle])
      end
    end

    private

    attr_reader :theme

    def normalize_value(field, value)
      case field["type"].to_s
      when "boolean"
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value.to_s
      end
    end
  end
end
