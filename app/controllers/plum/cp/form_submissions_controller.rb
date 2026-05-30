module Plum
  module Cp
    class FormSubmissionsController < BaseController
      before_action :set_form_definition
      before_action :set_form_submission

      def show
      end

      def destroy
        @form_submission.destroy
        redirect_to cp_form_definition_path(@form_definition), notice: "Submission deleted"
      end

      private

      def set_form_definition
        @form_definition = current_site.form_definitions.find(params[:form_definition_id])
      end

      def set_form_submission
        @form_submission = @form_definition.form_submissions.find(params[:id])
      end
    end
  end
end
