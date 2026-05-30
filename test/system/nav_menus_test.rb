require "application_system_test_case"

class NavMenusTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    @content_type = Plum::ContentType.create!(
      name: "Pages",
      handle: "pages",
      blueprint: { "fields" => [] }
    )
    @entry = Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "About",
      slug: "about",
      status: :published,
      published_at: 1.hour.ago,
      data: {}
    )

    login_as(@admin)
  end

  test "creating a menu with custom and entry items" do
    visit cp_nav_menus_path
    click_link "New Menu"

    fill_in "Name", with: "Main"
    fill_in "Handle", with: "main"
    click_button "Create Nav menu"

    assert_text "Navigation menu created"
    assert_text "nav.main.items"

    click_link "Add Item"
    fill_in "Label", with: "Menu"
    fill_in "Custom URL", with: "/menu"
    fill_in "Position", with: "1"
    click_button "Create Nav item"

    assert_text "Navigation item created"
    assert_text "Menu"
    assert_text "/menu"

    click_link "Add Item"
    fill_in "Label", with: "About"
    select "About (Pages)", from: "Entry"
    fill_in "Position", with: "2"
    click_button "Create Nav item"

    assert_text "Navigation item created"
    assert_text "About"
    assert_text "/about"
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
