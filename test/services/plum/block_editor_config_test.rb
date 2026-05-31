require "test_helper"
require "tmpdir"
require "yaml"

module Plum
  class BlockEditorConfigTest < ActiveSupport::TestCase
    test "turns theme blocks into block editor configs" do
      with_theme do |theme|
        config = BlockEditorConfig.new(theme).to_h

        handles = config["blocks"].map { |b| b["id"] }
        assert_equal %w[hero rich_text], handles

        hero = config["blocks"].find { |b| b["id"] == "hero" }
        assert_equal "Hero", hero["label"]
        assert_equal "Blocks", hero["category"]
        assert_equal %w[heading image], hero["fields"].map { |f| f["handle"] }
        assert_equal "text", hero["fields"].first["type"]
        assert_equal "Heading", hero["fields"].first["label"]
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

        assert_equal "hero", parsed.dig("blocks", 0, "id")
      end
    end

    test "is empty for a theme with no blocks" do
      Dir.mktmpdir do |dir|
        root = Pathname(dir).join("plain")
        FileUtils.mkdir_p(root)
        root.join("theme.yml").write("name: Plain\nhandle: plain\n")
        theme = Theme.new(root: root, manifest: YAML.safe_load(root.join("theme.yml").read))

        assert_equal [], BlockEditorConfig.new(theme).blocks
      end
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
              label: Hero
              fields:
                - handle: heading
                  type: text
                  label: Heading
                - handle: image
                  type: image
                  label: Background Image
            - handle: rich_text
              label: Rich Text
              fields:
                - handle: body
                  type: rich_text
                  label: Body
        YAML
        theme = Theme.new(root: root, manifest: YAML.safe_load(root.join("theme.yml").read))
        yield theme
      end
    end
  end
end
