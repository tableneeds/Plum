require "test_helper"

module Plum
  class ThemeSettingsParamsTest < ActiveSupport::TestCase
    test "normalizes values against theme manifest fields" do
      theme = ThemeRegistry.new.find("bagel-shop")

      settings = ThemeSettingsParams.new(theme).normalize(
        "accent_color" => "#123456",
        "hero_note" => "Fresh today",
        "show_powered_by" => "1",
        "ignored" => "value"
      )

      assert_equal(
        {
          "accent_color" => "#123456",
          "hero_note" => "Fresh today",
          "show_powered_by" => true,
          "corner_style" => "soft"
        },
        settings
      )
    end

    test "uses manifest defaults for missing settings" do
      theme = ThemeRegistry.new.find("bagel-shop")

      settings = ThemeSettingsParams.new(theme).normalize({})

      assert_equal "#1f6f63", settings["accent_color"]
      assert_equal "Boiled, baked, and ready early.", settings["hero_note"]
      assert_equal true, settings["show_powered_by"]
      assert_equal "soft", settings["corner_style"]
    end

    test "falls back to a valid select option" do
      theme = ThemeRegistry.new.find("bagel-shop")

      settings = ThemeSettingsParams.new(theme).normalize("corner_style" => "giant")

      assert_equal "soft", settings["corner_style"]
    end
  end
end
