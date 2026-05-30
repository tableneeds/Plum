module Plum
  module Cp
    module ThemeSettingsHelper
      def theme_setting_label(field)
        field["label"].presence || field["handle"].to_s.humanize
      end

      def theme_setting_options(field)
        Array(field["options"]).filter_map do |option|
          if option.is_a?(Hash)
            normalized = option.deep_stringify_keys
            value = normalized["value"].to_s
            next if value.blank?

            [ normalized["label"].presence || value.humanize, value ]
          else
            value = option.to_s
            next if value.blank?

            [ value.humanize, value ]
          end
        end
      end
    end
  end
end
