module Plum
  class FormSubmission < ApplicationRecord
    include SiteScoped

    belongs_to :form_definition

    validates :data, presence: true
    validate :required_fields_are_present
    validate :email_fields_are_valid
    validate :select_values_are_valid

    before_validation :normalize_data

    def data
      super || {}
    end

    def value(key)
      data&.dig(key)
    end

    private

    def normalize_data
      self.data = form_definition.form_fields.each_with_object({}) do |field, normalized|
        handle = field["handle"].to_s
        value = data[handle]

        normalized[handle] = normalized_value(field, value)
      end
    end

    def normalized_value(field, value)
      case field["type"]
      when "checkbox"
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value.to_s.strip
      end
    end

    def required_fields_are_present
      form_definition.form_fields.each do |field|
        next unless ActiveModel::Type::Boolean.new.cast(field["required"])

        value = data[field["handle"].to_s]
        next if field["type"] == "checkbox" ? value == true : value.present?

        errors.add(:data, "#{field_label(field)} is required")
      end
    end

    def email_fields_are_valid
      form_definition.form_fields.select { |field| field["type"] == "email" }.each do |field|
        value = data[field["handle"].to_s]
        next if value.blank? || URI::MailTo::EMAIL_REGEXP.match?(value)

        errors.add(:data, "#{field_label(field)} must be a valid email")
      end
    end

    def select_values_are_valid
      form_definition.form_fields.select { |field| field["type"] == "select" }.each do |field|
        value = data[field["handle"].to_s]
        options = Array(field["options"]).map(&:to_s)
        next if value.blank? || options.empty? || options.include?(value)

        errors.add(:data, "#{field_label(field)} is invalid")
      end
    end

    def field_label(field)
      field["label"].presence || field["handle"].to_s.humanize
    end
  end
end
