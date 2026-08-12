require "test_helper"

module Plum
  class EntryHomepageDestroyTest < ActiveSupport::TestCase
    test "the homepage refuses direct destruction" do
      site = Plum::Site.create!(name: "Guarded", theme_name: "default", skip_defaults: true)
      pages = site.content_types.create!(name: "Pages", handle: "homepage_guard_pages",
        blueprint: { "fields" => [] })
      home = pages.entries.create!(site: site, title: "Home", slug: Plum::Entry::HOMEPAGE_SLUG,
        status: :published, published_at: 1.hour.ago)

      assert_not home.destroy
      assert Plum::Entry.exists?(home.id)
      assert_includes home.errors[:base].join, "homepage"
    end

    test "destroying a site with a homepage entry succeeds" do
      # Regression: the homepage guard used to abort the site's dependent
      # cascade, which broke site destroy and plum:site:replace (the CLI
      # `plum pull`) on any real site — every real site has a homepage.
      site = Plum::Site.create!(name: "Doomed home", theme_name: "default", skip_defaults: true)
      pages = site.content_types.create!(name: "Pages", handle: "homepage_cascade_pages",
        blueprint: { "fields" => [] })
      home = pages.entries.create!(site: site, title: "Home", slug: Plum::Entry::HOMEPAGE_SLUG,
        status: :published, published_at: 1.hour.ago)

      assert site.destroy!
      assert_not Plum::Entry.exists?(home.id)
    end
  end
end
