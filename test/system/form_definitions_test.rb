require "application_system_test_case"

class FormDefinitionsTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    login_as(@admin)
  end

  test "creating a form and viewing a submission" do
    visit cp_form_definitions_path
    click_link "New Form"

    fill_in "Name", with: "Contact"
    fill_in "Handle", with: "contact"
    fill_in "Notification Email", with: "owner@example.com"

    click_button "Add Field"
    within "[data-plum--form-fields-target='fields'] [data-plum--form-fields-target='field']:last-child" do
      find("input[data-field='handle']").fill_in with: "email"
      find("input[data-field='label']").fill_in with: "Email"
      find("select[data-field='type']").select "Email"
      find("input[data-field='required']").check
    end

    click_button "Create Form"

    assert_text "Form created"
    assert_text "{% form \"contact\" %}"
    assert_text "Email"

    form = Plum::FormDefinition.find_by!(handle: "contact")
    form.form_submissions.create!(site: form.site, data: { "email" => "ben@example.com" })

    visit cp_form_definition_path(form)
    assert_text "ben@example.com"

    click_link "View"
    assert_text "Submission"
    assert_text "ben@example.com"
  end

  private

  def login_as(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Dashboard"
  end
end
