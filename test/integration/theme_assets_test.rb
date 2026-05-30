require "test_helper"

class ThemeAssetsTest < ActionDispatch::IntegrationTest
  test "serves bundled theme assets" do
    get "/theme_assets/default/theme.css"

    assert_response :success
    assert_equal "text/css", response.media_type
    assert_includes response.body, "color-scheme: light"
  end

  test "returns 404 for missing theme assets" do
    get "/theme_assets/default/missing.css"

    assert_response :not_found
  end

  test "returns 404 for path traversal attempts" do
    get "/theme_assets/default/%2E%2E/theme.yml"

    assert_response :not_found
  end
end
