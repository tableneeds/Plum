module Plum
  class ContentType < ApplicationRecord
    include SiteScoped
    include StaticCacheInvalidation

    FIELD_TYPES = FieldTypeRegistry.handles.freeze

    has_many :entries, dependent: :destroy

    validates :name, presence: true
    validates :handle, presence: true, uniqueness: { scope: :site_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validate :route_prefix_format
    validate :blueprint_fields_are_valid

    before_validation :generate_handle, on: :create

    def fields
      blueprint&.dig("fields") || []
    end

    def route_prefix
      blueprint&.dig("route_prefix").presence
    end

    private

    def generate_handle
      self.handle = name&.parameterize(separator: "_") if handle.blank?
    end

    def route_prefix_format
      return if route_prefix.blank? || route_prefix.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)

      errors.add(:blueprint, "route prefix must contain lowercase letters, numbers, and hyphens")
    end

    def blueprint_fields_are_valid
      handles = fields.map { |field| field["handle"].to_s }
      fields.each do |field|
        handle = field["handle"].to_s
        type = field["type"].to_s
        errors.add(:blueprint, "field handle #{handle.inspect} is invalid") unless handle.match?(/\A[a-z][a-z0-9_]*\z/)
        errors.add(:blueprint, "field #{handle.presence || '(unnamed)'} has unknown type #{type.inspect}") unless FieldTypeRegistry.include?(type)
        validate_nested_fields(field, handle) if %w[group repeater].include?(type)
        validate_collection_configuration(field, handle) if %w[list repeater images].include?(type) || (type == "relationship" && ActiveModel::Type::Boolean.new.cast(field["multiple"]))
        validate_number_configuration(field, handle) if type == "number"
        validate_presentation_configuration(field, handle, handles)
      end
    end

    def validate_presentation_configuration(field, handle, handles)
      width = Integer(field["width"], exception: false) if field["width"].present?
      errors.add(:blueprint, "field #{handle} width must be between 1 and 12") if field["width"].present? && (!width || !width.between?(1, 12))

      condition = field["condition"]
      return if condition.blank?

      source = condition["field"].to_s
      operator = condition["operator"].to_s
      errors.add(:blueprint, "field #{handle} condition references an unknown field") unless handles.include?(source) && source != handle
      unless %w[equals not_equals contains empty not_empty].include?(operator)
        errors.add(:blueprint, "field #{handle} condition has an invalid operator")
      end
    end

    def validate_collection_configuration(field, handle)
      minimum = Integer(field["min_items"], exception: false) if field["min_items"].present?
      maximum = Integer(field["max_items"], exception: false) if field["max_items"].present?
      errors.add(:blueprint, "field #{handle} minimum items must be zero or greater") if field["min_items"].present? && (!minimum || minimum.negative?)
      errors.add(:blueprint, "field #{handle} maximum items must be zero or greater") if field["max_items"].present? && (!maximum || maximum.negative?)
      errors.add(:blueprint, "field #{handle} maximum items must be at least its minimum") if minimum && maximum && maximum < minimum
    end

    def validate_number_configuration(field, handle)
      minimum = Float(field["min"], exception: false) if field["min"].present?
      maximum = Float(field["max"], exception: false) if field["max"].present?
      step = Float(field["step"], exception: false) if field["step"].present?
      errors.add(:blueprint, "field #{handle} minimum must be numeric") if field["min"].present? && !minimum
      errors.add(:blueprint, "field #{handle} maximum must be numeric") if field["max"].present? && !maximum
      errors.add(:blueprint, "field #{handle} step must be greater than zero") if field["step"].present? && (!step || !step.positive?)
      errors.add(:blueprint, "field #{handle} maximum must be at least its minimum") if minimum && maximum && maximum < minimum
    end

    def validate_nested_fields(field, parent_handle)
      nested_fields = Array(field["fields"])
      errors.add(:blueprint, "field #{parent_handle} must define nested fields") if nested_fields.empty?

      nested_fields.each do |nested|
        nested_handle = nested["handle"].to_s
        nested_type = nested["type"].to_s
        errors.add(:blueprint, "field #{parent_handle} has invalid nested handle #{nested_handle.inspect}") unless nested_handle.match?(/\A[a-z][a-z0-9_]*\z/)
        unless FieldTypeRegistry::NESTED_FIELD_TYPES.include?(nested_type)
          errors.add(:blueprint, "field #{parent_handle}.#{nested_handle.presence || '(unnamed)'} has unsupported nested type #{nested_type.inspect}")
        end
      end
    end
  end
end
