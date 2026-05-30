require "test_helper"

module Plum
  class LiquidContextTest < ActiveSupport::TestCase
    setup do
      Plum.configuration.content_sources.clear
    end

    teardown do
      Plum.configuration.content_sources.clear
    end

    test "adds registered content sources to the Liquid context" do
      site = Plum::Site.create!(name: "Bagel Boy", theme_name: "default")
      controller = fake_controller

      Plum.register_content_source(:restaurant) do |context|
        {
          "name" => context.site.name,
          "request_path" => context.request.path
        }
      end

      context = LiquidContext.new(controller: controller, site: site).to_h

      assert_equal "Bagel Boy", context.dig("restaurant", "name")
      assert_equal "/from-host", context.dig("restaurant", "request_path")
    end

    test "adds mounted theme asset base URL to the site context" do
      site = Plum::Site.create!(name: "Bagel Boy", theme_name: "bagel-shop")
      controller = fake_controller(script_name: "/website")

      context = LiquidContext.new(controller: controller, site: site).to_h

      assert_equal "/website/theme_assets/bagel-shop", context.dig("site", "theme_asset_base_url")
    end

    test "expands image field ids into asset objects" do
      site = Plum::Site.create!(name: "Bagel Boy", theme_name: "default")
      content_type = site.content_types.create!(
        name: "Posts",
        handle: "posts",
        blueprint: {
          "fields" => [
            { "handle" => "hero_image", "type" => "image", "label" => "Hero Image" }
          ]
        }
      )
      asset = site.assets.build(alt_text: "Tray of bagels", caption: "Morning batch")
      attach_test_png(asset, filename: "hero.png")
      asset.save!
      entry = content_type.entries.create!(
        site: site,
        title: "Fresh Today",
        slug: "fresh-today",
        status: :published,
        published_at: 1.hour.ago,
        data: { "hero_image" => asset.id }
      )

      context = LiquidContext.new(controller: fake_controller, site: site, entry: entry).to_h

      assert_equal "Tray of bagels", context.dig("entry", "data", "hero_image", "alt_text")
      assert_equal "Morning batch", context.dig("entry", "data", "hero_image", "caption")
      assert_includes context.dig("entry", "data", "hero_image", "url"), "/rails/active_storage/blobs"
    end

    test "exposes globals and navigation menus" do
      site = Plum::Site.create!(name: "Bagel Boy", theme_name: "default")
      site.globals.create!(
        name: "Company Info",
        handle: "company",
        data: {
          "phone" => "555-0100",
          "address" => "123 Bagel Street"
        }
      )
      content_type = site.content_types.create!(
        name: "Pages",
        handle: "pages",
        blueprint: { "fields" => [] }
      )
      entry = content_type.entries.create!(
        site: site,
        title: "About",
        slug: "about",
        status: :published,
        published_at: 1.hour.ago,
        data: {}
      )
      menu = site.nav_menus.create!(name: "Main", handle: "main")
      menu.nav_items.create!(site: site, label: "Home", url: "/", position: 1)
      menu.nav_items.create!(site: site, label: "About", entry: entry, position: 2)

      context = LiquidContext.new(controller: fake_controller(script_name: "/website"), site: site).to_h

      assert_equal "555-0100", context.dig("globals", "company", "phone")
      assert_equal "Main", context.dig("nav", "main", "name")
      assert_equal "Home", context.dig("nav", "main", "items", 0, "label")
      assert_equal "/", context.dig("nav", "main", "items", 0, "url")
      assert_equal "About", context.dig("nav", "main", "items", 1, "label")
      assert_equal "/website/about", context.dig("nav", "main", "items", 1, "url")
    end

    private

    def fake_controller(script_name: "")
      request = ActionDispatch::TestRequest.create
      request.path = "/from-host"
      request.script_name = script_name

      Struct.new(:request) do
        def params
          {}
        end

        def session
          {}
        end
      end.new(request)
    end
  end
end
