require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(
      email: "test@example.com",
      password: "password123",
      role: :admin
    )
  end

  test "visiting login page" do
    visit login_path
    assert_selector "h2", text: "Sign in to your account"
  end

  test "logging in with valid credentials" do
    visit login_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "password123"
    click_button "Sign in"

    assert_current_path cp_root_path
    assert_text "Dashboard"
  end

  test "logging in with invalid credentials" do
    visit login_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "wrongpassword"
    click_button "Sign in"

    assert_text "Invalid email or password"
  end

  test "logging out" do
    visit login_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "password123"
    click_button "Sign in"

    click_button "Logout"
    assert_current_path login_path
  end

  test "accessing control panel without login redirects to login" do
    visit cp_root_path
    assert_current_path login_path
  end
end
