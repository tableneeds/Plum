module Plum
  module Cp
    class EntriesController < BaseController
      before_action :set_content_type
      before_action :set_entry, only: [ :show, :edit, :update, :destroy ]
      before_action :set_assets, only: [ :new, :create, :edit, :update ]

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

      def set_assets
        @assets = current_site.assets.with_attached_file.order(created_at: :desc)
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
          normalize_entry_data_fields(entry)
          return true
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
        true
      end

      def normalize_entry_data_fields(entry)
        entry.data ||= {}

        @content_type.fields.each do |field|
          handle = field["handle"].to_s
          next if handle.blank?

          value = entry.data[handle]
          entry.data[handle] = normalized_field_value(field, value)
        end
      end

      def normalized_field_value(field, value)
        case field["type"]
        when "boolean"
          ActiveModel::Type::Boolean.new.cast(value)
        when "image"
          value.present? ? value.to_i : nil
        else
          value
        end
      end

      def image_fields
        @content_type.fields.select { |field| field["type"] == "image" && field["handle"].present? }
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
