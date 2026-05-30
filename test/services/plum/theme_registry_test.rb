require "test_helper"
require "tmpdir"

module Plum
  class ThemeRegistryTest < ActiveSupport::TestCase
    test "discovers themes from manifests" do
      Dir.mktmpdir do |dir|
        theme_root = Pathname(dir).join("restaurant")
        FileUtils.mkdir_p(theme_root)
        theme_root.join("theme.yml").write(<<~YAML)
          name: Restaurant
          handle: restaurant
          version: 1.2.3
          author: Plum
          description: Built for restaurants.
        YAML

        theme = ThemeRegistry.new(theme_paths: [ dir ]).find("restaurant")

        assert_equal "Restaurant", theme.name
        assert_equal "restaurant", theme.handle
        assert_equal "1.2.3", theme.version
        assert_equal "Plum", theme.author
        assert_equal "Built for restaurants.", theme.description
      end
    end

    test "earlier theme paths win when handles overlap" do
      Dir.mktmpdir do |host_dir|
        Dir.mktmpdir do |gem_dir|
          build_theme(host_dir, "default", "Host Default")
          build_theme(gem_dir, "default", "Gem Default")

          theme = ThemeRegistry.new(theme_paths: [ host_dir, gem_dir ]).find("default")

          assert_equal "Host Default", theme.name
        end
      end
    end

    test "bundled themes include default and bagel shop" do
      handles = ThemeRegistry.new(theme_paths: [ Rails.root.join("app/themes") ]).all.map(&:handle)

      assert_includes handles, "default"
      assert_includes handles, "bagel-shop"
    end

    private

    def build_theme(base_dir, handle, name)
      theme_root = Pathname(base_dir).join(handle)
      FileUtils.mkdir_p(theme_root)
      theme_root.join("theme.yml").write(<<~YAML)
        name: #{name}
        handle: #{handle}
      YAML
    end
  end
end
