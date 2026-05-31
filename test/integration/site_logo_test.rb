require "test_helper"

class SiteLogoTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!
    @settings = Plum::SiteSetting.instance(@site)
    @settings.update!(name: "Bagel Boy", theme_name: "default")
  end

  test "renders the site name when no logo is set" do
    @settings.update!(logo: nil)

    get root_path

    assert_response :success
    assert_includes response.body, "Bagel Boy"
    refute_includes response.body, "class=\"site-logo\""
  end

  test "renders the logo image when a logo asset is set" do
    asset = @site.assets.build(alt_text: "Bagel Boy logo")
    attach_test_png(asset)
    asset.save!
    @settings.update!(logo: asset.id.to_s)

    get root_path

    assert_response :success
    assert_includes response.body, "class=\"site-logo\""
    assert_includes response.body, asset.url
  end
end
