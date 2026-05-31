require "test_helper"
require "tmpdir"
require "yaml"

module Plum
  class BlockEditorConfigTest < ActiveSupport::TestCase
    test "merges theme blocks with the engine base blocks" do
      with_theme do |theme|
        config = BlockEditorConfig.new(theme).to_h
        handles = config["blocks"].map { |b| b["id"] }

        # base blocks are present...
        assert_includes handles, "gallery"
        assert_includes handles, "cta"
        # ...and the theme's own block is too.
        assert_includes handles, "menu_section"

        menu = config["blocks"].find { |b| b["id"] == "menu_section" }
        assert_equal "Menu Section", menu["label"]
        assert_equal "Blocks", menu["category"]
        assert_equal %w[heading], menu["fields"].map { |f| f["handle"] }
      end
    end

    test "a theme block overrides the base block with the same handle" do
      with_theme do |theme|
        config = BlockEditorConfig.new(theme).to_h
        heroes = config["blocks"].select { |b| b["id"] == "hero" }

        assert_equal 1, heroes.size
        assert_equal "Fancy Hero", heroes.first["label"]
      end
    end

    test "limits blocks to an allowed whitelist" do
      with_theme do |theme|
        config = BlockEditorConfig.new(theme, allowed: %w[rich_text]).to_h

        assert_equal %w[rich_text], config["blocks"].map { |b| b["id"] }
      end
    end

    test "serializes to JSON" do
      with_theme do |theme|
        parsed = JSON.parse(BlockEditorConfig.new(theme).to_json)

        assert parsed["blocks"].any?
      end
    end

    test "with no theme still offers the base blocks" do
      handles = BlockEditorConfig.new(nil).blocks.map { |b| b["id"] }

      assert_includes handles, "hero"
      assert_includes handles, "rich_text"
    end

    private

    def with_theme
      Dir.mktmpdir do |dir|
        root = Pathname(dir).join("blocky")
        FileUtils.mkdir_p(root.join("blocks"))
        root.join("theme.yml").write(<<~YAML)
          name: Blocky
          handle: blocky
          blocks:
            - handle: hero
              label: Fancy Hero
              fields:
                - handle: heading
                  type: text
                  label: Heading
            - handle: menu_section
              label: Menu Section
              fields:
                - handle: heading
                  type: text
                  label: Heading
        YAML
        theme = Theme.new(root: root, manifest: YAML.safe_load(root.join("theme.yml").read))
        yield theme
      end
    end
  end
end
