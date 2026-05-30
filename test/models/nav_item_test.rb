require "test_helper"

module Plum
  class NavItemTest < ActiveSupport::TestCase
    setup do
      @site = Site.create!(name: "Bagel Boy", theme_name: "default")
      @menu = @site.nav_menus.create!(name: "Main", handle: "main")
    end

    test "requires a custom URL when no entry is selected" do
      item = @menu.nav_items.build(site: @site, label: "Menu")

      refute item.valid?
      assert_includes item.errors[:url], "can't be blank"
    end

    test "allows entry backed items without custom URLs" do
      content_type = @site.content_types.create!(
        name: "Pages",
        handle: "pages",
        blueprint: { "fields" => [] }
      )
      entry = content_type.entries.create!(
        site: @site,
        title: "About",
        slug: "about",
        status: :published,
        published_at: 1.hour.ago,
        data: {}
      )

      item = @menu.nav_items.build(site: @site, label: "About", entry: entry)

      assert item.valid?
    end

    test "rejects entries from another site" do
      other_site = Site.create!(name: "Other", theme_name: "default")
      content_type = other_site.content_types.create!(
        name: "Pages",
        handle: "pages",
        blueprint: { "fields" => [] }
      )
      entry = content_type.entries.create!(
        site: other_site,
        title: "Other",
        slug: "other",
        status: :published,
        published_at: 1.hour.ago,
        data: {}
      )

      item = @menu.nav_items.build(site: @site, label: "Other", entry: entry)

      refute item.valid?
      assert_includes item.errors[:entry], "must belong to the same site"
    end

    test "rejects parent cycles" do
      parent = @menu.nav_items.create!(site: @site, label: "Parent", url: "/", position: 1)
      child = @menu.nav_items.create!(site: @site, label: "Child", url: "/child", parent: parent, position: 2)

      parent.parent = child

      refute parent.valid?
      assert_includes parent.errors[:parent], "cannot be a descendant"
    end
  end
end
