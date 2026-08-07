module Plum
  module Cp
    class FieldsetsController < BaseController
      before_action :require_admin

      def index
        @fieldsets = current_site.fieldsets.order(:name)
        @content_types = current_site.content_types.order(:name)
      end

      def create
        source = current_site.content_types.find(params.require(:fieldset)[:content_type_id])
        fieldset = current_site.fieldsets.build(fieldset_params.except(:content_type_id))
        fieldset.fields = source.fields.deep_dup
        if fieldset.save
          redirect_to cp_fieldsets_path, notice: "Fieldset created from #{source.name}"
        else
          @fieldsets = current_site.fieldsets.order(:name)
          @content_types = current_site.content_types.order(:name)
          @fieldset = fieldset
          render :index, status: :unprocessable_entity
        end
      end

      def destroy
        current_site.fieldsets.find(params[:id]).destroy!
        redirect_to cp_fieldsets_path, notice: "Fieldset deleted"
      end

      private

      def fieldset_params
        params.require(:fieldset).permit(:name, :handle, :content_type_id)
      end
    end
  end
end
