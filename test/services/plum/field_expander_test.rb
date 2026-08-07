require "test_helper"

module Plum
  class FieldExpanderTest < ActiveSupport::TestCase
    setup do
      @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    end

    test "leaves plain fields untouched" do
      result = FieldExpander.new(site: @site).expand(
        values: { "heading" => "Hi", "count" => 3 },
        fields: [
          { "handle" => "heading", "type" => "text" },
          { "handle" => "count", "type" => "number" }
        ]
      )

      assert_equal "Hi", result["heading"]
      assert_equal 3, result["count"]
    end

    test "expands a relationship id into a published entry hash" do
      content_type = @site.content_types.create!(name: "Posts", handle: "posts", blueprint: { "fields" => [] })
      related = @site.entries.create!(
        content_type: content_type, title: "Related", slug: "related",
        status: :published, published_at: Time.current, data: {}
      )

      result = FieldExpander.new(site: @site).expand(
        values: { "featured" => related.id },
        fields: [ { "handle" => "featured", "type" => "relationship" } ]
      )

      assert_equal "Related", result.dig("featured", "title")
      assert_equal "/related", result.dig("featured", "url")
    end

    test "does not expand an unpublished relationship" do
      content_type = @site.content_types.create!(name: "Posts", handle: "posts", blueprint: { "fields" => [] })
      draft = @site.entries.create!(
        content_type: content_type, title: "Draft", slug: "draft", status: :draft, data: {}
      )

      result = FieldExpander.new(site: @site).expand(
        values: { "featured" => draft.id },
        fields: [ { "handle" => "featured", "type" => "relationship" } ]
      )

      assert_nil result["featured"]
    end

    test "expands multiple relationships in their stored order" do
      content_type = @site.content_types.create!(name: "Posts", handle: "posts", blueprint: { "fields" => [] })
      first = @site.entries.create!(content_type: content_type, title: "First", slug: "first", status: :published, published_at: 1.hour.ago, data: {})
      second = @site.entries.create!(content_type: content_type, title: "Second", slug: "second", status: :published, published_at: 1.hour.ago, data: {})
      result = FieldExpander.new(site: @site).expand(
        values: { "related" => [ second.id, first.id ] },
        fields: [ { "handle" => "related", "type" => "relationship", "multiple" => true } ]
      )

      assert_equal [ "Second", "First" ], result["related"].map { |entry| entry["title"] }
    end

    test "expands an ordered image collection" do
      first = @site.assets.create!(alt_text: "First", file: { io: StringIO.new(TEST_PNG_DATA), filename: "first.png", content_type: "image/png" })
      second = @site.assets.create!(alt_text: "Second", file: { io: StringIO.new(TEST_PNG_DATA), filename: "second.png", content_type: "image/png" })

      result = FieldExpander.new(site: @site).expand(
        values: { "gallery" => [ second.id, first.id ] },
        fields: [ { "handle" => "gallery", "type" => "images" } ]
      )

      assert_equal [ "Second", "First" ], result["gallery"].map { |asset| asset["alt_text"] }
    end
  end
end
