module Plum
  module FieldOptions
    module_function

    def pairs(options)
      Array(options).filter_map do |option|
        if option.is_a?(Hash)
          value = option["value"] || option[:value]
          label = option["label"] || option[:label] || value
          [ label.to_s, value.to_s ] if value.present?
        elsif option.present?
          [ option.to_s, option.to_s ]
        end
      end
    end

    def editor_value(options)
      pairs(options).map { |label, value| label == value ? label : "#{label} | #{value}" }.join("\n")
    end
  end
end
