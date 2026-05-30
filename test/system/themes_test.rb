require "application_system_test_case"
require "tmpdir"
require "zip"

class ThemesTest < ApplicationSystemTestCase
  setup do
    @theme_dir = Dir.mktmpdir("plum-system-themes")
    @previous_theme_paths = Plum.configuration.theme_paths
    Plum.configuration.theme_paths = [ @theme_dir, Rails.root.join("app/themes") ]

    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )

    login_as(@admin)
  end

  teardown do
    Plum.configuration.theme_paths = @previous_theme_paths
    FileUtils.remove_entry(@theme_dir) if @theme_dir && Dir.exist?(@theme_dir)
  end

  test "installing and activating a theme package" do
    zip_path = Pathname(@theme_dir).join("counter-theme.zip")
    build_theme_zip(zip_path)

    visit cp_themes_path

    assert_text "Default"
    assert_text "Bagel Shop"

    attach_file "Theme zip", zip_path
    click_button "Install Theme"

    assert_text "Theme installed"
    assert_text "Counter Theme"

    within "[data-theme-handle='counter-theme']" do
      click_button "Activate"
    end

    assert_text "Theme activated"

    visit root_path
    assert_text "Counter theme for My Site"
  end

  private

  def login_as(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Dashboard"
  end

  def build_theme_zip(zip_path)
    Zip::File.open(zip_path, create: true) do |zip|
      zip.get_output_stream("theme.yml") do |stream|
        stream.write(<<~YAML)
          name: Counter Theme
          handle: counter-theme
          version: 1.0.0
        YAML
      end
      zip.get_output_stream("layouts/base.liquid") do |stream|
        stream.write("<main>{{ content }}</main>")
      end
      zip.get_output_stream("templates/index.liquid") do |stream|
        stream.write("Counter theme for {{ site.name }}")
      end
    end
  end
end
