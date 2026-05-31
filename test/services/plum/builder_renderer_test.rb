require "test_helper"
require "tmpdir"
require "yaml"

module Plum
  class BuilderRendererTest < ActiveSupport::TestCase
    test "renders blocks via theme partials with block fields and shared assigns" do
      with_theme do |theme|
        html = BuilderRenderer.new(
          blocks: [ { "id" => "1", "type" => "hero", "fields" => { "heading" => "Hi" } } ],
          base_assigns: { "site" => { "name" => "Bagel Boy" } },
          site: nil,
          theme: theme
        ).render

        assert_includes html, "<section>Hi for Bagel Boy</section>"
      end
    end

    test "renders multiple blocks in order" do
      with_theme do |theme|
        html = BuilderRenderer.new(
          blocks: [
            { "id" => "1", "type" => "hero", "fields" => { "heading" => "First" } },
            { "id" => "2", "type" => "hero", "fields" => { "heading" => "Second" } }
          ],
          base_assigns: { "site" => { "name" => "Plum" } },
          site: nil,
          theme: theme
        ).render

        assert_operator html.index("First"), :<, html.index("Second")
      end
    end

    test "skips unknown block types without raising" do
      with_theme do |theme|
        html = BuilderRenderer.new(
          blocks: [ { "id" => "1", "type" => "ghost", "fields" => {} } ],
          base_assigns: {},
          site: nil,
          theme: theme
        ).render

        assert_equal "", html.to_s.strip
      end
    end

    private

    def with_theme
      Dir.mktmpdir do |dir|
        theme_root = Pathname(dir).join("blocky")
        FileUtils.mkdir_p(theme_root.join("blocks"))
        theme_root.join("theme.yml").write(<<~YAML)
          name: Blocky
          handle: blocky
          blocks:
            - handle: hero
              label: Hero
              fields:
                - handle: heading
                  type: text
                  label: Heading
        YAML
        theme_root.join("blocks/hero.liquid").write(
          "<section>{{ block.heading }} for {{ site.name }}</section>"
        )

        theme = Theme.new(root: theme_root, manifest: YAML.safe_load(theme_root.join("theme.yml").read))
        yield theme
      end
    end
  end
end
