require "test_helper"

class ControlPanelRelationshipFieldsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @other_site = Plum::Site.create!(name: "Other Site", skip_defaults: true)
    @admin = Plum::User.create!(
      email: "admin@example.com",
      password: "password123",
      role: :admin
    )
    @posts = @site.content_types.create!(
      name: "Posts",
      handle: "posts",
      blueprint: { "fields" => [] }
    )
    @pages = @site.content_types.create!(
      name: "Pages",
      handle: "pages",
      blueprint: {
        "fields" => [
          {
            "handle" => "featured_post",
            "type" => "relationship",
            "label" => "Featured Post",
            "content_type" => "posts"
          }
        ]
      }
    )
    other_posts = @other_site.content_types.create!(
      name: "Posts",
      handle: "posts",
      blueprint: { "fields" => [] }
    )
    @other_entry = other_posts.entries.create!(
      site: @other_site,
      title: "Other Site Post",
      slug: "other-site-post",
      status: :draft,
      data: {}
    )

    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "rejects relationship values from another site" do
    post cp_content_type_entries_path(@pages),
      params: {
        entry: {
          title: "Homepage",
          status: "draft",
          data: {
            featured_post: @other_entry.id
          }
        }
      }

    assert_response :unprocessable_entity
    assert_includes response.body, "Featured Post is not a valid entry"
    assert_nil @pages.entries.find_by(slug: "homepage")
  end
end
