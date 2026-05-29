require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "instance creates brief-aligned defaults" do
    setting = Plum::SiteSetting.instance

    assert_equal "My Site", setting.name
    assert_equal "default", setting.theme_name
    assert_equal "#7c3aed", setting.primary_color
  end

  test "support email must be valid when present" do
    setting = Plum::SiteSetting.new(name: "Example", support_email: "not-an-email")

    assert_not setting.valid?
    assert_includes setting.errors[:support_email], "is invalid"
  end
end
