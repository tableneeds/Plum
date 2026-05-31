require "test_helper"
require "tmpdir"
require "yaml"

module Plum
  class BlockLibraryTest < ActiveSupport::TestCase
    test "with no theme, exposes the engine base blocks" do
      library = BlockLibrary.new(nil)
      handles = library.definitions.map { |d| d["handle"] }

      assert_includes handles, "hero"
      assert_includes handles, "rich_text"
      assert_includes handles, "gallery"
      assert library.definition("cta")
      assert library.template("cta").present?
    end

    test "a theme block with a new handle is appended to the base blocks" do
      with_theme(<<~YAML) do |theme|
        name: Restaurant
        handle: restaurant
        blocks:
          - handle: menu_section
            label: Menu Section
            fields:
              - handle: heading
                type: text
                label: Heading
      YAML
        library = BlockLibrary.new(theme)
        handles = library.definitions.map { |d| d["handle"] }

        assert_includes handles, "hero"        # base
        assert_includes handles, "menu_section" # theme
        assert_equal "Menu Section", library.definition("menu_section")["label"]
      end
    end

    test "a theme block overrides a base block with the same handle" do
      with_theme(<<~YAML, partial: [ "hero", "<section>themed hero {{ block.tagline }}</section>" ]) do |theme|
        name: Override
        handle: override
        blocks:
          - handle: hero
            label: Fancy Hero
            fields:
              - handle: tagline
                type: text
                label: Tagline
      YAML
        library = BlockLibrary.new(theme)

        # Only one hero, and it's the theme's version.
        heroes = library.definitions.select { |d| d["handle"] == "hero" }
        assert_equal 1, heroes.size
        assert_equal "Fancy Hero", library.definition("hero")["label"]
        assert_includes library.template("hero"), "themed hero"
      end
    end

    private

    def with_theme(yaml, partial: nil)
      Dir.mktmpdir do |dir|
        root = Pathname(dir).join("t")
        FileUtils.mkdir_p(root.join("blocks"))
        root.join("theme.yml").write(yaml)
        if partial
          handle, source = partial
          root.join("blocks", "#{handle}.liquid").write(source)
        end
        yield Theme.new(root: root, manifest: YAML.safe_load(yaml))
      end
    end
  end
end
