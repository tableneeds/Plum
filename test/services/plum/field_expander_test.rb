require "test_helper"

module Plum
  class FieldExpanderTest < ActiveSupport::TestCase
    setup do
      @site = Plum::Site.first_or_create_standalone!
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
  end
end
