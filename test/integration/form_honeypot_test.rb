require "test_helper"

class FormHoneypotTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    Plum::SiteSetting.instance(@site).update!(name: "Bagel Boy", theme_name: "default")
    @form = @site.form_definitions.create!(
      name: "Contact",
      handle: "contact",
      fields: [ { "handle" => "message", "type" => "textarea", "label" => "Message", "required" => false, "options" => [] } ]
    )
  end

  test "rendered forms include the honeypot and no session CSRF token" do
    get root_path

    assert_response :success
    assert_includes response.body, 'name="form_submission[website]"'
    refute_includes response.body, "authenticity_token"
  end

  test "submissions with a filled honeypot are silently dropped" do
    assert_no_difference -> { @form.form_submissions.count } do
      post form_path("contact"), params: {
        return_to: root_path,
        form_submission: { website: "http://spam.example", data: { message: "buy now" } }
      }
    end

    assert_redirected_to root_path
  end

  test "legitimate submissions still work without a CSRF token" do
    assert_difference -> { @form.form_submissions.count }, 1 do
      post form_path("contact"), params: {
        return_to: root_path,
        form_submission: { website: "", data: { message: "Do you cater?" } }
      }
    end

    assert_redirected_to root_path
  end
end
