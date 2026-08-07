require "test_helper"

class ContentApiTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @posts = @site.content_types.create!(
      name: "Posts", handle: "api_posts", blueprint: { "route_prefix" => "journal", "fields" => [ { "handle" => "summary", "type" => "text" } ] }
    )
    @published = @posts.entries.create!(site: @site, title: "Published", slug: "published", status: :published, published_at: 1.hour.ago, data: { "summary" => "Public" })
    @posts.entries.create!(site: @site, title: "Draft", slug: "draft", status: :draft, data: { "summary" => "Private" })
  end

  test "lists only live collection entries with pagination metadata" do
    get api_v1_collection_entries_path(@posts.handle), params: { per_page: 10 }

    assert_response :success
    payload = response.parsed_body
    assert_equal [ "Published" ], payload["data"].map { |entry| entry["title"] }
    assert_equal "Public", payload.dig("data", 0, "data", "summary")
    assert_equal 1, payload.dig("meta", "total")
    assert_equal "/journal/published", payload.dig("data", 0, "url")
  end

  test "shows a live entry and rejects drafts" do
    get api_v1_collection_entry_path(@posts.handle, @published.slug)
    assert_response :success
    assert_equal @published.id, response.parsed_body.dig("data", "id")

    get api_v1_collection_entry_path(@posts.handle, "draft")
    assert_response :not_found
  end

  test "caps page size" do
    get api_v1_collection_entries_path(@posts.handle), params: { per_page: 1_000 }

    assert_equal 100, response.parsed_body.dig("meta", "per_page")
  end
end
