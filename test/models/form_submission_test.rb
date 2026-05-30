require "test_helper"

module Plum
  class FormSubmissionTest < ActiveSupport::TestCase
    setup do
      @site = Site.create!(name: "Bagel Boy", theme_name: "default")
      @form = @site.form_definitions.create!(
        name: "Contact",
        handle: "contact",
        fields: [
          { "handle" => "name", "type" => "text", "label" => "Name", "required" => true, "options" => [] },
          { "handle" => "email", "type" => "email", "label" => "Email", "required" => true, "options" => [] },
          { "handle" => "topic", "type" => "select", "label" => "Topic", "required" => false, "options" => [ "Catering", "General" ] },
          { "handle" => "subscribe", "type" => "checkbox", "label" => "Subscribe", "required" => false, "options" => [] }
        ]
      )
    end

    test "normalizes data to defined fields" do
      submission = @form.form_submissions.create!(
        site: @site,
        data: {
          "name" => " Ben ",
          "email" => "ben@example.com",
          "topic" => "Catering",
          "subscribe" => "1",
          "ignored" => "value"
        }
      )

      assert_equal({
        "name" => "Ben",
        "email" => "ben@example.com",
        "topic" => "Catering",
        "subscribe" => true
      }, submission.data)
    end

    test "validates required fields and email fields" do
      submission = @form.form_submissions.build(site: @site, data: { "email" => "not-email" })

      refute submission.valid?
      assert_includes submission.errors[:data], "Name is required"
      assert_includes submission.errors[:data], "Email must be a valid email"
    end

    test "rejects unknown select options" do
      submission = @form.form_submissions.build(
        site: @site,
        data: {
          "name" => "Ben",
          "email" => "ben@example.com",
          "topic" => "Other"
        }
      )

      refute submission.valid?
      assert_includes submission.errors[:data], "Topic is invalid"
    end
  end
end
