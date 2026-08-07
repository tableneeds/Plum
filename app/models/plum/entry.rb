module Plum
  class Entry < ApplicationRecord
    include SiteScoped

    belongs_to :content_type
    belongs_to :author, class_name: "Plum::User", optional: true
    belongs_to :origin, class_name: "Plum::Entry", optional: true

    has_many :entry_terms, dependent: :destroy
    has_many :terms, through: :entry_terms
    has_many :revisions, class_name: "Plum::EntryRevision", dependent: :destroy
    has_many :translations, class_name: "Plum::Entry", foreign_key: :origin_id, dependent: :destroy

    # The page served at "/" — Plum resolves the homepage by this slug
    # (convention over configuration). Its slug is locked and it can't be
    # deleted while published, so a non-technical editor can't orphan the home
    # page by renaming or removing it.
    HOMEPAGE_SLUG = "home".freeze

    enum :status, { draft: 0, published: 1, scheduled: 2 }

    validates :title, presence: true
    validates :slug, presence: true, uniqueness: { scope: [ :site_id, :locale ] }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    validates :locale, presence: true, format: { with: /\A[a-z]{2}(?:-[A-Z]{2})?\z/ }
    validate :origin_matches_site_and_content_type
    validates :status, presence: true
    validate :homepage_slug_is_unchanged
    validate :required_blueprint_fields_are_present
    validate :blueprint_field_values_are_valid

    before_validation :generate_slug
    before_validation :set_default_locale, on: :create
    before_validation :set_published_at, if: :published?
    before_destroy :prevent_homepage_destroy

    scope :live, -> { published.where("published_at <= ?", Time.current) }
    scope :search, ->(query) {
      return none if query.blank?

      term = "%#{query}%"
      where("title LIKE ? OR slug LIKE ?", term, term)
    }

    def field_value(handle)
      data&.dig(handle)
    end

    def homepage?
      slug == HOMEPAGE_SLUG
    end

    def record_revision!(editor: nil)
      identity = revision_editor_identity(editor)
      attributes = {
        site: site,
        editor_name: identity[:name],
        editor_email: identity[:email],
        editor_gid: identity[:gid],
        snapshot: {
          "title" => title,
          "slug" => slug,
          "status" => status,
          "published_at" => published_at&.iso8601,
          "data" => data.to_h.deep_dup,
          "term_ids" => term_ids
        }
      }
      attributes[:editor] = editor if editor.is_a?(Plum::User)
      revisions.create!(attributes)
    end

    def restore_revision!(revision, editor: nil)
      raise ArgumentError, "Revision does not belong to this entry" unless revision.entry_id == id && revision.site_id == site_id

      snapshot = revision.snapshot.to_h
      transaction do
        update!(snapshot.slice("title", "slug", "status", "published_at", "data"))
        self.term_ids = site.terms.where(id: Array(snapshot["term_ids"])).pluck(:id)
        record_revision!(editor: editor)
      end
    end

    def translation_group
      source = origin || self
      [ source, *source.translations ].uniq.sort_by(&:locale)
    end

    private

    def set_default_locale
      self.locale = site&.default_locale if locale.blank?
    end

    def origin_matches_site_and_content_type
      return unless origin

      errors.add(:origin, "must belong to the same site") if origin.site_id != site_id
      errors.add(:origin, "must use the same content type") if origin.content_type_id != content_type_id
      errors.add(:origin, "cannot itself be a translation") if origin.origin_id.present?
    end

    def revision_editor_identity(editor)
      return {} unless editor

      {
        name: editor.respond_to?(:name) ? editor.name : nil,
        email: editor.respond_to?(:email) ? editor.email : nil,
        gid: editor.respond_to?(:to_global_id) ? editor.to_global_id.to_s : nil
      }
    end

    def generate_slug
      self.slug = title&.parameterize if slug.blank?
    end

    def homepage_slug_is_unchanged
      return unless persisted? && slug_changed? && slug_was == HOMEPAGE_SLUG

      errors.add(:slug, "can't be changed — this is the homepage")
    end

    def required_blueprint_fields_are_present
      content_type&.fields.to_a.each do |field|
        next if field["type"] == "section"
        next unless blueprint_field_visible?(field)

        handle = field["handle"].to_s
        value = if field["type"] == "taxonomy"
          terms.joins(:taxonomy).where(plum_taxonomies: { handle: field["taxonomy"].to_s }).exists?
        else
          data&.dig(handle)
        end
        value = parsed_structured_validation_value(value) if %w[group repeater].include?(field["type"])

        validate_required_value(field, value, field["label"].presence || handle.titleize)
      end
    end

    def parsed_structured_validation_value(value)
      return value unless value.is_a?(String)

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end

    def validate_required_value(field, value, path)
      if ActiveModel::Type::Boolean.new.cast(field["required"]) && value != false && value.blank?
        errors.add(:data, "#{path} is required")
        return
      end

      case field["type"]
      when "group"
        values = value.respond_to?(:to_h) ? value.to_h : {}
        validate_required_nested_fields(field, values, path)
      when "repeater"
        Array(value).each_with_index do |row, index|
          values = row.respond_to?(:to_h) ? row.to_h : {}
          validate_required_nested_fields(field, values, "#{path} row #{index + 1}")
        end
      end
    end

    def validate_required_nested_fields(field, values, path)
      Array(field["fields"]).each do |nested_field|
        handle = nested_field["handle"].to_s
        validate_required_value(nested_field, values[handle], "#{path} #{nested_field['label'].presence || handle.titleize}")
      end
    end

    def blueprint_field_values_are_valid
      content_type&.fields.to_a.each do |field|
        next if field["type"] == "section"
        next unless blueprint_field_visible?(field)

        value = data&.dig(field["handle"].to_s)
        value = parsed_structured_validation_value(value) if %w[list repeater].include?(field["type"])
        label = field["label"].presence || field["handle"].to_s.titleize

        case field["type"]
        when "list", "repeater", "images"
          validate_collection_constraints(field, Array(value), label)
        when "relationship"
          validate_collection_constraints(field, Array(value), label) if ActiveModel::Type::Boolean.new.cast(field["multiple"])
        when "number"
          validate_number_constraints(field, value, label)
        when "date"
          validate_date_constraints(field, value, label)
        when "select", "radio", "button_group", "checkboxes"
          validate_option_values(field, value, label)
        else
          validate_custom_field(definition: FieldTypeRegistry.find(field["type"]), field: field, value: value, label: label)
        end
      end
    end

    def validate_custom_field(definition:, field:, value:, label:)
      return unless definition&.validator

      messages = definition.validator.call(value: value, field: field, entry: self)
      Array(messages).select(&:present?).each { |message| errors.add(:data, "#{label} #{message}") }
    end

    def blueprint_field_visible?(field)
      condition = field["condition"]
      return true if condition.blank?

      values = Array(data&.dig(condition["field"].to_s)).map(&:to_s)
      expected = condition["value"].to_s
      case condition["operator"]
      when "equals" then values.include?(expected)
      when "not_equals" then !values.include?(expected)
      when "contains" then values.any? { |value| value.include?(expected) }
      when "empty" then values.empty? || values.all?(&:blank?)
      when "not_empty" then values.any?(&:present?)
      else true
      end
    end

    def validate_option_values(field, value, label)
      return if value.blank?

      allowed = FieldOptions.pairs(field["options"]).map(&:last)
      invalid = Array(value).map(&:to_s) - allowed
      errors.add(:data, "#{label} contains an invalid option") if invalid.any?
    end

    def validate_collection_constraints(field, values, label)
      minimum = field["min_items"].presence&.to_i
      maximum = field["max_items"].presence&.to_i
      errors.add(:data, "#{label} must have at least #{minimum} items") if minimum && values.length < minimum
      errors.add(:data, "#{label} must have no more than #{maximum} items") if maximum && values.length > maximum
      if field["type"] == "list" && ActiveModel::Type::Boolean.new.cast(field["unique"])
        normalized = values.map { |value| value.to_s.strip.downcase }.reject(&:blank?)
        errors.add(:data, "#{label} values must be unique") if normalized.uniq.length != normalized.length
      end
    end

    def validate_number_constraints(field, value, label)
      return if value.blank?

      number = BigDecimal(value.to_s)
      if field["number_kind"] == "integer" && number.frac.nonzero?
        errors.add(:data, "#{label} must be a whole number")
      end
      errors.add(:data, "#{label} must be at least #{field['min']}") if field["min"].present? && number < BigDecimal(field["min"].to_s)
      errors.add(:data, "#{label} must be no more than #{field['max']}") if field["max"].present? && number > BigDecimal(field["max"].to_s)
      if field["step"].present? && BigDecimal(field["step"].to_s).positive?
        base = field["min"].present? ? BigDecimal(field["min"].to_s) : 0
        errors.add(:data, "#{label} does not match the required step") unless ((number - base) % BigDecimal(field["step"].to_s)).zero?
      end
    rescue ArgumentError
      errors.add(:data, "#{label} must be a number")
    end

    def validate_date_constraints(field, value, label)
      return if value.blank?

      parsed = parsed_temporal_value(value, field["date_mode"])
      minimum = parsed_temporal_value(field["min"], field["date_mode"]) if field["min"].present?
      maximum = parsed_temporal_value(field["max"], field["date_mode"]) if field["max"].present?
      errors.add(:data, "#{label} must be on or after #{field['min']}") if minimum && parsed < minimum
      errors.add(:data, "#{label} must be on or before #{field['max']}") if maximum && parsed > maximum
    rescue ArgumentError
      errors.add(:data, "#{label} is not a valid #{field['date_mode'].presence || 'date'}")
    end

    def parsed_temporal_value(value, mode)
      case mode
      when "time"
        Time.strptime(value.to_s, "%H:%M")
      when "datetime"
        Time.zone.parse(value.to_s) || raise(ArgumentError)
      else
        Date.iso8601(value.to_s)
      end
    end

    def prevent_homepage_destroy
      return unless homepage?

      errors.add(:base, "The homepage can't be deleted")
      throw :abort
    end

    def set_published_at
      self.published_at ||= Time.current
    end
  end
end
