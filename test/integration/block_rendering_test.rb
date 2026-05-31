require "test_helper"

module Plum
  class BlockRenderingTest < ActionDispatch::IntegrationTest
    test "renders an entry's blocks field as HTML on the public page" do
      site = Plum::Site.first_or_create_standalone!
      Plum::SiteSetting.instance(site).update!(name: "Bagel Boy", theme_name: "default")

      content_type = site.content_types.create!(
        name: "Landing", handle: "landing",
        blueprint: { "fields" => [ { "handle" => "sections", "type" => "blocks" } ] }
      )
      site.entries.create!(
        content_type: content_type, title: "Welcome", slug: "welcome",
        status: :published, published_at: Time.current,
        data: {
          "sections" => [
            { "id" => "1", "type" => "hero", "fields" => { "heading" => "Hello Blocks" } },
            { "id" => "2", "type" => "rich_text", "fields" => { "body" => "Composed from **blocks**." } }
          ]
        }
      )

      get "/welcome"

      assert_response :success
      assert_includes response.body, "Hello Blocks"
      assert_includes response.body, "<strong>blocks</strong>"
    end
  end
end
