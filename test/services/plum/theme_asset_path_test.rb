require "test_helper"

module Plum
  class ThemeAssetPathTest < ActiveSupport::TestCase
    test "builds encoded asset URLs from safe relative paths" do
      url = ThemeAssetPath.url(base_url: "/website/theme_assets/bagel-shop", path: "fonts/Plum Display.woff2")

      assert_equal "/website/theme_assets/bagel-shop/fonts/Plum%20Display.woff2", url
    end

    test "returns a blank URL for unsafe paths" do
      assert_equal "", ThemeAssetPath.url(base_url: "/theme_assets/default", path: "../theme.yml")
      assert_equal "", ThemeAssetPath.url(base_url: "/theme_assets/default", path: "/etc/passwd")
      assert_equal "", ThemeAssetPath.url(base_url: "/theme_assets/default", path: "")
    end
  end
end
