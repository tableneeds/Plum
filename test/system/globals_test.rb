require "application_system_test_case"

class GlobalsTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    login_as(@admin)
  end

  test "creating and editing a global" do
    visit cp_globals_path
    click_link "New Global"

    fill_in "Name", with: "Company Info"
    fill_in "Handle", with: "company"
    fill_in "Data", with: JSON.pretty_generate({ phone: "555-0100", city: "Pensacola" })
    click_button "Create Global"

    assert_text "Global created"
    assert_text "globals.company"
    assert_text "555-0100"

    click_link "Edit"
    fill_in "Data", with: JSON.pretty_generate({ phone: "555-0101", city: "Pensacola" })
    click_button "Update Global"

    assert_text "Global updated"
    assert_text "555-0101"
  end

  test "rejecting invalid JSON" do
    visit new_cp_global_path

    fill_in "Name", with: "Company Info"
    fill_in "Data", with: "{"
    click_button "Create Global"

    assert_text "Data must be valid JSON"
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
