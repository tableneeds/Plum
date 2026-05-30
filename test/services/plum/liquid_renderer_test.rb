require "test_helper"
require "tmpdir"

module Plum
  class LiquidRendererTest < ActiveSupport::TestCase
    test "renders the selected theme from configured theme paths" do
      Dir.mktmpdir do |dir|
        theme_root = Pathname(dir).join("custom")
        FileUtils.mkdir_p(theme_root.join("layouts"))
        FileUtils.mkdir_p(theme_root.join("templates"))
        theme_root.join("theme.yml").write("name: Custom\nhandle: custom\n")
        theme_root.join("layouts/base.liquid").write("<main>{{ content }}</main>")
        theme_root.join("templates/index.liquid").write("Custom theme for {{ site.name }}")

        with_theme_paths([ dir, Rails.root.join("app/themes") ]) do
          html = LiquidRenderer.render_template("index", {
            "site" => { "name" => "Bagel Boy", "theme_name" => "custom" }
          })

          assert_includes html, "<main>Custom theme for Bagel Boy</main>"
        end
      end
    end

    test "falls back to bundled default templates" do
      Dir.mktmpdir do |dir|
        theme_root = Pathname(dir).join("custom")
        FileUtils.mkdir_p(theme_root)
        theme_root.join("theme.yml").write("name: Custom\nhandle: custom\n")

        with_theme_paths([ dir, Rails.root.join("app/themes") ]) do
          html = LiquidRenderer.render_template("index", {
            "site" => { "name" => "Fallback Site", "theme_name" => "custom" },
            "entries" => {}
          })

          assert_includes html, "Welcome to Fallback Site"
        end
      end
    end

    test "renders bundled bagel shop theme" do
      html = LiquidRenderer.render_template("index", {
        "site" => {
          "name" => "Bagel Boy",
          "tagline" => "Best bagels on the Gulf Coast",
          "theme_name" => "bagel-shop",
          "theme_settings" => { "hero_note" => "Hot bagels until noon." },
          "url" => "/"
        },
        "entries" => {
          "posts" => [
            { "title" => "Today at the counter", "url" => "/today-at-the-counter" }
          ]
        }
      })

      assert_includes html, "Fresh from the oven"
      assert_includes html, "Best bagels on the Gulf Coast"
      assert_includes html, "Hot bagels until noon."
      assert_includes html, "Shop Notes"
      assert_includes html, "/today-at-the-counter"
    end

    private

    def with_theme_paths(paths)
      previous_paths = Plum.configuration.theme_paths
      Plum.configuration.theme_paths = paths
      yield
    ensure
      Plum.configuration.theme_paths = previous_paths
    end
  end
end
