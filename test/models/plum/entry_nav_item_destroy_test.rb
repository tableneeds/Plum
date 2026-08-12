require "test_helper"

module Plum
  class EntryNavItemDestroyTest < ActiveSupport::TestCase
    test "destroying an entry removes its nav items instead of violating the FK" do
      site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      pages = site.content_types.create!(name: "Pages", handle: "nav_destroy_pages",
        blueprint: { "fields" => [] })
      entry = pages.entries.create!(site: site, title: "About", slug: "nav-destroy-about", status: :draft)
      menu = site.nav_menus.create!(name: "Main", handle: "nav_destroy_main")
      item = menu.nav_items.create!(site: site, label: "About", entry: entry, position: 0)

      assert_difference -> { Plum::NavItem.count }, -1 do
        entry.destroy!
      end
      assert_not Plum::NavItem.exists?(item.id)
    end

    test "destroying a site with nav-linked entries succeeds" do
      site = Plum::Site.create!(name: "Doomed", theme_name: "default", skip_defaults: true)
      pages = site.content_types.create!(name: "Pages", handle: "site_destroy_pages",
        blueprint: { "fields" => [] })
      entry = pages.entries.create!(site: site, title: "Linked", slug: "site-destroy-linked", status: :draft)
      menu = site.nav_menus.create!(name: "Main", handle: "site_destroy_main")
      menu.nav_items.create!(site: site, label: "Linked", entry: entry, position: 0)

      assert site.destroy!
    end
  end
end
