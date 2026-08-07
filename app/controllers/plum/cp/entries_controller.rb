module Plum
  module Cp
    class EntriesController < BaseController
      ALLOWED_RICH_TEXT_TAGS = %w[
        a action-text-attachment blockquote br code em figcaption figure
        h1 h2 h3 hr img li ol p pre s strong table tbody td th thead tr ul
      ].freeze
      ALLOWED_RICH_TEXT_ATTRIBUTES = %w[
        alt caption content-type filename filesize height href presentation
        rel sgid src target title url width
      ].freeze

      before_action :set_content_type
      before_action :set_entry, only: [ :edit, :update, :destroy, :image_field, :translate ]
      before_action :set_form_collections, only: [ :new, :create, :edit, :update ]
      before_action :require_editor, only: [ :new, :create, :edit, :update, :destroy, :image_field, :translate ]

      def index
        @entries = @content_type.entries.order(updated_at: :desc)
      end

      def new
        @entry = @content_type.entries.build(status: :draft, site: current_site, locale: current_site.default_locale)
      end

      def create
        @entry = @content_type.entries.build(entry_params)
        @entry.site = current_site
        @entry.author = current_user if current_user.is_a?(Plum::User)

        if save_entry(@entry)
          redirect_to edit_cp_content_type_entry_path(@content_type, @entry), notice: "Entry created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        @entry.assign_attributes(entry_params)

        if save_entry(@entry)
          redirect_to edit_cp_content_type_entry_path(@content_type, @entry), notice: "Entry updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # Persists one image association without submitting (and potentially
      # overwriting) the other edited fields on the page.
      def image_field
        handle = params[:field_handle].to_s
        field = image_fields.find { |candidate| candidate["handle"].to_s == handle }
        return render json: { error: "Unknown image field" }, status: :unprocessable_entity unless field

        asset_id = params[:asset_id].presence
        if asset_id && !current_site.assets.exists?(id: asset_id)
          return render json: { error: "Image is not available" }, status: :unprocessable_entity
        end

        data = @entry.data.to_h.merge(handle => asset_id&.to_i)
        if @entry.update(data: data)
          render json: { saved: true, asset_id: data[handle] }
        else
          render json: { error: @entry.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        @entry.destroy
        redirect_to cp_content_type_entries_path(@content_type), notice: "Entry deleted"
      end

      def translate
        locale = params[:locale].to_s
        unless current_site.locales.include?(locale)
          return redirect_to edit_cp_content_type_entry_path(@content_type, @entry), alert: "Locale is not configured"
        end

        source = @entry.origin || @entry
        translation = source.translations.find_or_initialize_by(locale: locale)
        if translation.new_record?
          translation.assign_attributes(
            site: current_site,
            content_type: @content_type,
            author: current_user.is_a?(Plum::User) ? current_user : nil,
            title: @entry.title,
            slug: @entry.slug,
            status: :draft,
            data: @entry.data.to_h.deep_dup
          )
          translation.save!
        end
        redirect_to edit_cp_content_type_entry_path(@content_type, translation), notice: "#{locale} translation ready"
      end

      private

      def set_content_type
        @content_type = current_site.content_types.find(params[:content_type_id])
      end

      def set_entry
        @entry = @content_type.entries.find(params[:id])
      end

      def set_form_collections
        @assets = current_site.assets.with_attached_file.order(created_at: :desc)
        @theme = current_site.theme
        @relationship_entries_by_field = relationship_fields.each_with_object({}) do |field, entries_by_field|
          entries_by_field[field["handle"].to_s] = relationship_entry_scope(@entry, field).order(:title)
        end
        @taxonomy_terms_by_field = taxonomy_fields.each_with_object({}) do |field, terms_by_field|
          taxonomy = current_site.taxonomies.find_by(handle: field["taxonomy"].to_s)
          terms_by_field[field["handle"].to_s] = taxonomy ? taxonomy.terms.ordered : []
        end
      end

      def entry_params
        permitted = params.require(:entry).permit(:title, :slug, :status, :published_at, :locale)
        if params[:entry][:data].is_a?(ActionController::Parameters)
          permitted[:data] = params[:entry][:data].permit!.to_h
        end
        permitted
      end

      def save_entry(entry)
        saved = false
        entry.transaction do
          unless attach_uploaded_image_fields(entry) && entry.valid? && entry.save
            raise ActiveRecord::Rollback
          end

          sync_entry_terms(entry)
          entry.record_revision!(editor: current_user)
          saved = true
        end
        saved
      end

      def sync_entry_terms(entry)
        submitted_ids = Array(params.dig(:entry, :term_ids)).map(&:to_i).select(&:positive?)
        valid_ids = Plum::Term.where(id: submitted_ids, site: current_site).pluck(:id)
        entry.term_ids = valid_ids
      end

      def attach_uploaded_image_fields(entry)
        image_uploads = params.dig(:entry, :image_uploads)
        unless image_uploads.respond_to?(:[])
          return normalize_entry_data_fields(entry)
        end

        image_fields.each do |field|
          handle = field["handle"].to_s
          upload = image_uploads[handle]
          next if upload.blank?

          asset = current_site.assets.build(
            file: upload,
            alt_text: default_asset_alt_text(entry, field),
            folder: field["folder"].presence || @content_type.handle
          )

          unless asset.save
            entry.errors.add(:base, "#{field_label(field)} #{asset.errors.full_messages.to_sentence}")
            return false
          end

          entry.data ||= {}
          entry.data[handle] = asset.id
        end

        normalize_entry_data_fields(entry)
      end

      def normalize_entry_data_fields(entry)
        entry.data ||= {}

        @content_type.fields.each do |field|
          handle = field["handle"].to_s
          next if handle.blank? || field["type"] == "section"

          value = entry.data[handle]
          entry.data[handle] = normalized_field_value(entry, field, value)
          return false if entry.errors.any?
        end

        true
      end

      def normalized_field_value(entry, field, value)
        definition = FieldTypeRegistry.find(field["type"])
        if definition&.normalizer
          return definition.normalizer.call(value: value, field: field, entry: entry, controller: self)
        end

        case field["type"]
        when "boolean"
          ActiveModel::Type::Boolean.new.cast(value)
        when "number"
          normalized_number_value(value, field)
        when "checkboxes"
          Array(value).select(&:present?)
        when "image"
          normalized_image_value(entry, field, value)
        when "images"
          normalized_asset_ids(entry, field, value)
        when "rich_text"
          value
        when "relationship"
          normalized_relationship_value(entry, field, value)
        when "blocks"
          normalized_blocks_value(value)
        when "list"
          Array(parsed_structured_value(value, fallback: [])).map { |item| item.to_s.strip }.select(&:present?)
        when "group"
          normalized_structured_row(field, parsed_structured_value(value, fallback: {}))
        when "repeater"
          Array(parsed_structured_value(value, fallback: [])).filter_map do |row|
            normalized = normalized_structured_row(field, row)
            normalized if normalized.values.any?(&:present?)
          end
        else
          value
        end
      end

      def normalized_asset_ids(entry, field, value)
        ids = Array(value).select(&:present?).map(&:to_i).uniq
        valid_ids = current_site.assets.where(id: ids).pluck(:id)
        if valid_ids.length != ids.length
          entry.errors.add(:base, "#{field_label(field)} contains an invalid image")
          return []
        end

        ids
      end

      def normalized_image_value(entry, field, value)
        return nil if value.blank?

        asset = current_site.assets.find_by(id: value.to_i)
        unless asset
          entry.errors.add(:base, "#{field_label(field)} is not a valid image")
          return nil
        end

        asset.update!(alt_text: default_asset_alt_text(entry, field)) if asset.alt_text.blank?
        asset.id
      end

      def normalized_number_value(value, field)
        return nil if value.blank?

        field["number_kind"] == "integer" ? Integer(value, 10) : Float(value)
      rescue ArgumentError, TypeError
        value
      end

      def parsed_structured_value(value, fallback:)
        return value unless value.is_a?(String)

        JSON.parse(value)
      rescue JSON::ParserError
        fallback
      end

      def normalized_structured_row(field, value)
        row = value.respond_to?(:to_h) ? value.to_h : {}
        Array(field["fields"]).each_with_object({}) do |nested_field, normalized|
          handle = nested_field["handle"].to_s
          next if handle.blank?

          nested_value = row[handle]
          nested_value = nested_field["default"] if nested_value.nil? && nested_field.key?("default")
          normalized[handle] = nested_field["type"] == "boolean" ? ActiveModel::Type::Boolean.new.cast(nested_value) : nested_value
        end
      end

      def normalized_relationship_value(entry, field, value)
        if ActiveModel::Type::Boolean.new.cast(field["multiple"])
          ids = Array(value).select(&:present?).map(&:to_i).uniq
          valid_ids = relationship_entry_scope(entry, field).where(id: ids).pluck(:id)
          if valid_ids.length != ids.length
            entry.errors.add(:base, "#{field_label(field)} contains an invalid entry")
            return []
          end
          return ids
        end

        return nil if value.blank?

        related_entry = relationship_entry_scope(entry, field).find_by(id: value.to_i)
        return related_entry.id if related_entry

        entry.errors.add(:base, "#{field_label(field)} is not a valid entry")
        nil
      end

      # A blocks field is submitted as a JSON string from the block editor. We
      # parse it and normalize each block instance to { id, type, fields }.
      def normalized_blocks_value(value)
        parsed = value.is_a?(String) ? safe_parse_blocks(value) : value
        return [] unless parsed.is_a?(Array)

        parsed.filter_map do |block|
          block = block.to_h if block.respond_to?(:to_h)
          next unless block.is_a?(Hash)

          type = block["type"].to_s
          next if type.blank?

          fields = block["fields"]
          fields = fields.to_h if fields.respond_to?(:to_h)

          {
            "id" => block["id"].presence || SecureRandom.uuid,
            "type" => type,
            "fields" => fields.is_a?(Hash) ? fields : {}
          }
        end
      end

      def safe_parse_blocks(value)
        JSON.parse(value)
      rescue JSON::ParserError
        []
      end

      def sanitized_rich_text(value)
        Rails::HTML5::SafeListSanitizer.new.sanitize(
          value.to_s,
          tags: ALLOWED_RICH_TEXT_TAGS,
          attributes: ALLOWED_RICH_TEXT_ATTRIBUTES
        )
      end

      def image_fields
        @content_type.fields.select { |field| field["type"] == "image" && field["handle"].present? }
      end

      def relationship_fields
        @content_type.fields.select { |field| field["type"] == "relationship" && field["handle"].present? }
      end

      def taxonomy_fields
        @content_type.fields.select { |field| field["type"] == "taxonomy" && field["handle"].present? }
      end

      def relationship_entry_scope(entry, field)
        site = entry&.site || current_site
        scope = Entry.for_site(site).includes(:content_type)
        target_handle = field["content_type"].to_s.strip.presence
        return scope unless target_handle

        scope.joins(:content_type).where(ContentType.table_name => { handle: target_handle })
      end

      def field_label(field)
        field["label"].presence || field["handle"].to_s.humanize
      end

      def default_asset_alt_text(entry, field)
        field["label"].present? ? "#{entry.title} #{field['label']}" : entry.title
      end
    end
  end
end
