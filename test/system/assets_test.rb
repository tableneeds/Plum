require "application_system_test_case"

class AssetsTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    @image_path = png_fixture_path(filename: "bagel.png")

    login_as(@admin)
  end

  teardown do
    FileUtils.rm_f(@image_path) if @image_path
  end

  test "uploading and editing an image asset" do
    visit cp_assets_path

    attach_file "Image", @image_path
    fill_in "Alt Text", with: "Fresh bagel tray"
    fill_in "Caption", with: "Morning batch"
    fill_in "Folder", with: "menu"
    click_button "Upload Asset"

    assert_text "Asset uploaded"
    assert_text "bagel.png"
    assert_text "Fresh bagel tray"
    assert_text "menu"

    click_link "Edit"
    assert_text "Edit Asset"
    fill_in "Alt Text", with: "Updated bagel tray"
    click_button "Save Asset"

    assert_text "Asset updated"
    assert_text "Updated bagel tray"
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
