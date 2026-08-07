require "application_system_test_case"

class SiteSettingsTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )

    Plum::SiteSetting.instance.update!(
      name: "Bagel Boy",
      tagline: "Best bagels on the Gulf Coast"
    )

    login_as(@admin)
  end

  test "switching themes saves theme settings and renders the selected theme" do
    visit edit_cp_site_settings_path

    select "Bagel Shop (bagel-shop)", from: "Theme"
    fill_in "Hero Note", with: "Hot bagels until noon."
    click_button "Save Settings"

    assert_text "Site settings updated"
    assert_text "Bagel Shop"
    assert_field "Hero Note", with: "Hot bagels until noon."

    visit root_path

    assert_text "FRESH FROM THE OVEN"
    assert_text "Best bagels on the Gulf Coast"
    assert_text "Hot bagels until noon."
  end

  test "previewing a theme does not require saving it first" do
    visit cp_theme_preview_path("bagel-shop")

    assert_text "FRESH FROM THE OVEN"
    assert_text "Bagel Boy"
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
