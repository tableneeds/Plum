module Plum
  class FormMailer < ApplicationMailer
    # Notifies the form's configured recipient that a new submission arrived.
    # The host application is responsible for configuring ActionMailer delivery
    # (SMTP, default_url_options, etc.); the engine only composes the message.
    def submission_notification(submission)
      @submission = submission
      @form = submission.form_definition
      @fields = @form.form_fields
      @site_name = Plum::SiteSetting.instance(submission.site).name

      mail(
        to: @form.notification_email,
        subject: "New submission: #{@form.name}"
      )
    end
  end
end
