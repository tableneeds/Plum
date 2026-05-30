module Plum
  class FormSubmissionsController < ApplicationController
    def create
      form_definition = current_site.form_definitions.find_by!(handle: params[:handle])
      submission = form_definition.form_submissions.build(
        site: current_site,
        data: submission_data(form_definition)
      )

      if submission.save
        redirect_to safe_return_path, notice: "Form submitted"
      else
        redirect_to safe_return_path, alert: submission.errors.full_messages.to_sentence
      end
    end

    private

    def submission_data(form_definition)
      raw_data = params.dig(:form_submission, :data)
      data = raw_data.respond_to?(:permit!) ? raw_data.permit!.to_h : {}

      form_definition.field_handles.index_with { |handle| data[handle] }
    end

    def safe_return_path
      return root_path unless params[:return_to].is_a?(String)

      return_to = params[:return_to]
      return root_path if return_to.blank? || return_to.start_with?("//") || return_to.match?(%r{\A[a-z][a-z0-9+.-]*://}i)

      return_to
    end
  end
end
