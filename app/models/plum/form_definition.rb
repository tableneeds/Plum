module Plum
  class FormDefinition < ApplicationRecord
    include SiteScoped
    include StaticCacheInvalidation

    FIELD_TYPES = %w[text email textarea select checkbox].freeze
    HANDLE_PATTERN = /\A[a-z][a-z0-9_]*\z/

    has_many :form_submissions, dependent: :destroy

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: HANDLE_PATTERN }
    validate :fields_are_valid

    before_validation :generate_handle, on: :create

    def form_fields
      fields || []
    end

    def field_handles
      form_fields.filter_map { |field| field["handle"].presence }
    end

    def to_liquid
      {
        "name" => name,
        "handle" => handle,
        "fields" => form_fields
      }
    end

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end

    def fields_are_valid
      unless form_fields.is_a?(Array)
        errors.add(:fields, "must be an array")
        return
      end

      seen_handles = []

      form_fields.each_with_index do |field, index|
        validate_field(field, index, seen_handles)
      end
    end

    def validate_field(field, index, seen_handles)
      unless field.is_a?(Hash)
        errors.add(:fields, "field #{index + 1} must be an object")
        return
      end

      handle = field["handle"].to_s
      type = field["type"].to_s

      errors.add(:fields, "field #{index + 1} handle is required") if handle.blank?
      errors.add(:fields, "#{handle} handle is invalid") if handle.present? && !handle.match?(HANDLE_PATTERN)
      errors.add(:fields, "#{handle} handle is duplicated") if handle.present? && seen_handles.include?(handle)
      errors.add(:fields, "#{handle} type is invalid") unless FIELD_TYPES.include?(type)

      seen_handles << handle if handle.present?
    end
  end
end
