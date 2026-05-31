module Plum
  module Cp
    class EntriesController < BaseController
      ALLOWED_RICH_TEXT_TAGS = %w[
        a blockquote br code em h1 h2 h3 hr li ol p pre s strong ul
      ].freeze
      ALLOWED_RICH_TEXT_ATTRIBUTES = %w[href rel target title].freeze

      before_action :set_content_type
      before_action :set_entry, only: [ :show, :edit, :update, :destroy ]
      before_action :set_form_collections, only: [ :new, :create, :edit, :update ]

      def index
        @entries = @content_type.entries.order(updated_at: :desc)
      end

      def show
      end

      def new
        @entry = @content_type.entries.build(status: :draft, site: current_site)
      end

      def create
        @entry = @content_type.entries.build(entry_params)
        @entry.site = current_site
        @entry.author = current_user if current_user.is_a?(Plum::User)

        if save_entry(@entry)
          redirect_to cp_content_type_entry_path(@content_type, @entry), notice: "Entry created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        @entry.assign_attributes(entry_params)

        if save_entry(@entry)
          redirect_to cp_content_type_entry_path(@content_type, @entry), notice: "Entry updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @entry.destroy
        redirect_to cp_content_type_entries_path(@content_type), notice: "Entry deleted"
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
      end

      def entry_params
        permitted = params.require(:entry).permit(:title, :slug, :status, :published_at)
        if params[:entry][:data].is_a?(ActionController::Parameters)
          permitted[:data] = params[:entry][:data].permit!.to_h
        end
        permitted
      end

      def save_entry(entry)
        return false unless entry.valid?
        return false unless attach_uploaded_image_fields(entry)

        entry.save
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
          next if handle.blank?

          value = entry.data[handle]
          entry.data[handle] = normalized_field_value(entry, field, value)
          return false if entry.errors.any?
        end

        true
      end

      def normalized_field_value(entry, field, value)
        case field["type"]
        when "boolean"
          ActiveModel::Type::Boolean.new.cast(value)
        when "image"
          value.present? ? value.to_i : nil
        when "rich_text"
          sanitized_rich_text(value)
        when "relationship"
          normalized_relationship_value(entry, field, value)
        when "blocks"
          normalized_blocks_value(value)
        else
          value
        end
      end

      def normalized_relationship_value(entry, field, value)
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
