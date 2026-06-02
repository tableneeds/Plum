require "test_helper"

class FormNotificationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    Plum::SiteSetting.instance(@site).update!(name: "Bagel Boy", theme_name: "default")
  end

  test "enqueues a notification email when the form has a notification_email" do
    @site.form_definitions.create!(
      name: "Contact", handle: "contact", notification_email: "owner@example.com",
      fields: [ { "handle" => "name", "type" => "text", "label" => "Name", "required" => true, "options" => [] } ]
    )

    assert_enqueued_emails 1 do
      post form_path("contact"), params: {
        return_to: root_path,
        form_submission: { data: { name: "Ben" } }
      }
    end

    assert_redirected_to root_path
  end

  test "does not enqueue when the form has no notification_email" do
    @site.form_definitions.create!(
      name: "Newsletter", handle: "newsletter", notification_email: nil,
      fields: [ { "handle" => "name", "type" => "text", "label" => "Name", "required" => true, "options" => [] } ]
    )

    assert_no_enqueued_emails do
      post form_path("newsletter"), params: {
        return_to: root_path,
        form_submission: { data: { name: "Ben" } }
      }
    end
  end
end
