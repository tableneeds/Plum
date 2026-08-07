module Plum
  module Cp
    class ContentTypesController < BaseController
      before_action :set_content_type, only: [ :show, :edit, :update, :destroy, :apply_fieldset ]
      before_action :require_admin, only: [ :new, :create, :edit, :update, :destroy, :apply_fieldset ]
      before_action :set_fieldsets, only: [ :new, :create, :edit, :update ]

      def index
        @content_types = ContentType.for_site(current_site)
      end

      def show
        @entries = @content_type.entries.order(updated_at: :desc)
      end

      def new
        @content_type = current_site.content_types.build
      end

      def create
        @content_type = current_site.content_types.build(content_type_params)
        if @content_type.save
          redirect_to cp_content_type_path(@content_type), notice: "Content type created"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @content_type.update(content_type_params)
          redirect_to cp_content_type_path(@content_type), notice: "Content type updated"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @content_type.destroy
        redirect_to cp_content_types_path, notice: "Content type deleted"
      end

      def apply_fieldset
        fieldset = current_site.fieldsets.find(params[:fieldset_id])
        existing_handles = @content_type.fields.map { |field| field["handle"].to_s }
        inserted_handles = Array(fieldset.fields).map { |field| field["handle"].to_s }
        collisions = existing_handles & inserted_handles
        if collisions.any?
          return render json: { error: "Field handles already exist: #{collisions.join(', ')}" }, status: :unprocessable_entity
        end

        blueprint = @content_type.blueprint.to_h.deep_dup
        blueprint["fields"] = @content_type.fields.deep_dup + Array(fieldset.fields).deep_dup
        if @content_type.update(blueprint: blueprint)
          render json: { applied: true, redirect_url: edit_cp_content_type_path(@content_type) }
        else
          render json: { error: @content_type.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      private

      def set_content_type
        @content_type = current_site.content_types.find(params[:id])
      end

      def content_type_params
        permitted = params.require(:content_type).permit(:name, :handle, :singleton, :icon, :blueprint)
        if permitted[:blueprint].is_a?(String)
          permitted[:blueprint] = JSON.parse(permitted[:blueprint]) rescue {}
        end
        permitted
      end

      def set_fieldsets
        @fieldsets = current_site.fieldsets.order(:name)
      end
    end
  end
end
