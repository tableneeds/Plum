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
          "show_powered_by" => true
        },
        settings
      )
    end
  end
end
