require "test_helper"

module Plum
  class FormMailerTest < ActionMailer::TestCase
    setup do
      @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      Plum::SiteSetting.instance(@site).update!(name: "Bagel Boy")
      @form = @site.form_definitions.create!(
        name: "Contact",
        handle: "contact",
        notification_email: "owner@example.com",
        fields: [
          { "handle" => "name", "type" => "text", "label" => "Name", "required" => false, "options" => [] },
          { "handle" => "message", "type" => "textarea", "label" => "Message", "required" => false, "options" => [] }
        ]
      )
      @submission = @form.form_submissions.create!(
        site: @site, data: { "name" => "Ben", "message" => "Do you cater?" }
      )
    end

    test "builds a notification to the form's recipient listing the submitted fields" do
      email = Plum::FormMailer.submission_notification(@submission)

      assert_equal [ "owner@example.com" ], email.to
      assert_match "Contact", email.subject
      body = email.body.encoded
      assert_match "Ben", body
      assert_match "Do you cater?", body
      assert_match "Bagel Boy", body
    end

    test "uses the configured mailer_sender as the from address" do
      previous = Plum.configuration.mailer_sender
      Plum.configuration.mailer_sender = "hello@plum.test"

      email = Plum::FormMailer.submission_notification(@submission)

      assert_equal [ "hello@plum.test" ], email.from
    ensure
      Plum.configuration.mailer_sender = previous
    end
  end
end
