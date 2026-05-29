module Plum
  module Cp
    class EntriesController < BaseController
      before_action :set_content_type
      before_action :set_entry, only: [ :show, :edit, :update, :destroy ]

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
        if @entry.save
          redirect_to cp_content_type_entry_path(@content_type, @entry), notice: "Entry created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @entry.update(entry_params)
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

      def entry_params
        permitted = params.require(:entry).permit(:title, :slug, :status, :published_at)
        if params[:entry][:data].is_a?(ActionController::Parameters)
          permitted[:data] = params[:entry][:data].permit!.to_h
        end
        permitted
      end
    end
  end
end
