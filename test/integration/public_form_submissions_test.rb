require "test_helper"

class PublicFormSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    Plum::SiteSetting.instance(@site).update!(name: "Bagel Boy", theme_name: "default")
    @form = @site.form_definitions.create!(
      name: "Contact",
      handle: "contact",
      fields: [
        { "handle" => "name", "type" => "text", "label" => "Name", "required" => true, "options" => [] },
        { "handle" => "email", "type" => "email", "label" => "Email", "required" => true, "options" => [] },
        { "handle" => "message", "type" => "textarea", "label" => "Message", "required" => true, "options" => [] }
      ]
    )
  end

  test "renders a contact form through the bundled theme" do
    get root_path

    assert_response :success
    assert_includes response.body, 'action="/forms/contact"'
    assert_includes response.body, 'name="form_submission[data][email]"'
    assert_includes response.body, "Contact"
  end

  test "creates a site scoped public submission" do
    assert_difference -> { @form.form_submissions.count }, 1 do
      post form_path("contact"), params: {
        return_to: root_path,
        form_submission: {
          data: {
            name: "Ben",
            email: "ben@example.com",
            message: "Do you cater?"
          }
        }
      }
    end

    assert_redirected_to root_path
    submission = @form.form_submissions.last
    assert_equal @site, submission.site
    assert_equal "Ben", submission.value("name")
    assert_equal "ben@example.com", submission.value("email")
  end

  test "does not create invalid submissions" do
    assert_no_difference -> { @form.form_submissions.count } do
      post form_path("contact"), params: {
        return_to: root_path,
        form_submission: {
          data: {
            name: "",
            email: "not-email",
            message: ""
          }
        }
      }
    end

    assert_redirected_to root_path
  end
end
