require "test_helper"

module Plum
  class HomepageConventionTest < ActiveSupport::TestCase
    setup do
      @site = Plum::Site.first_or_create_standalone!
      @type = @site.content_types.create!(name: "Pages", handle: "pages", blueprint: { "fields" => [] })
      @home = @site.entries.create!(
        content_type: @type, title: "Home", slug: "home",
        status: :published, published_at: Time.current, data: {}
      )
    end

    test "the home page is recognized as the homepage" do
      assert @home.homepage?
    end

    test "the homepage slug cannot be changed" do
      @home.slug = "start"
      assert_not @home.valid?
      assert_includes @home.errors[:slug].to_sentence, "homepage"
    end

    test "the homepage cannot be destroyed" do
      assert_equal false, @home.destroy
      assert Plum::Entry.exists?(@home.id)
    end

    test "a non-home page has no such restrictions" do
      page = @site.entries.create!(
        content_type: @type, title: "About", slug: "about",
        status: :published, published_at: Time.current, data: {}
      )
      page.slug = "about-us"
      assert page.valid?
      assert page.destroy
    end
  end
end
