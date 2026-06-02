require "test_helper"

class PublicLiquidRenderingTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(
      email: "admin@example.com",
      password: "password123",
      role: :admin
    )

    Plum::SiteSetting.instance(@site).update!(
      name: "Bagel Boy",
      tagline: "Best bagels on the Gulf Coast",
      seo_title: "Bagel Boy Bakery",
      seo_description: "Fresh bagels and coffee in Pensacola.",
      primary_color: "#6d28d9",
      support_email: "hello@example.com"
    )

    @posts = @site.content_types.create!(
      name: "Blog Posts",
      handle: "posts",
      blueprint: {
        "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" },
          { "handle" => "hero_image", "type" => "image", "label" => "Hero Image" }
        ]
      }
    )
  end

  test "homepage exposes live entries by content type handle" do
    create_entry(title: "Visible Post", slug: "visible-post", status: :published, published_at: 1.hour.ago)
    create_entry(title: "Draft Post", slug: "draft-post", status: :draft)
    create_entry(title: "Future Post", slug: "future-post", status: :published, published_at: 1.day.from_now)
    create_entry(title: "Scheduled Post", slug: "scheduled-post", status: :scheduled, published_at: 1.hour.ago)

    get root_path

    assert_response :success
    assert_includes response.body, "Bagel Boy"
    assert_includes response.body, "Best bagels on the Gulf Coast"
    assert_includes response.body, "Fresh bagels and coffee in Pensacola."
    assert_includes response.body, "Visible Post"
    assert_includes response.body, "/visible-post"
    refute_includes response.body, "Draft Post"
    refute_includes response.body, "Future Post"
    refute_includes response.body, "Scheduled Post"
  end

  test "homepage renders the main navigation menu" do
    @site.nav_menus.create!(name: "Main", handle: "main").tap do |menu|
      menu.nav_items.create!(site: @site, label: "About", url: "/about", position: 1)
    end

    get root_path

    assert_response :success
    assert_includes response.body, "About"
    assert_includes response.body, "/about"
  end

  test "scheduled entries are not public pages" do
    create_entry(title: "Scheduled Post", slug: "scheduled-post", status: :scheduled, published_at: 1.hour.ago)

    get "/scheduled-post"

    assert_response :not_found
  end

  test "published entry renders through content type template" do
    create_entry(
      title: "Menu Update",
      slug: "menu-update",
      status: :published,
      published_at: 1.hour.ago,
      data: { "body" => "Try the **sesame** bagel." }
    )

    get "/menu-update"

    assert_response :success
    assert_includes response.body, "Menu Update"
    assert_includes response.body, "<strong>sesame</strong>"
  end

  test "published entry renders image fields through Liquid" do
    asset = @site.assets.build(alt_text: "Bagel tray", caption: "Morning batch")
    attach_test_png(asset, filename: "bagels.png")
    asset.save!
    create_entry(
      title: "Image Post",
      slug: "image-post",
      status: :published,
      published_at: 1.hour.ago,
      data: {
        "body" => "Image body",
        "hero_image" => asset.id
      }
    )

    get "/image-post"

    assert_response :success
    assert_includes response.body, "Bagel tray"
    assert_includes response.body, "/rails/active_storage/blobs"
  end

  private

  def create_entry(attributes)
    @posts.entries.create!(
      {
        site: @site,
        author: @admin,
        title: attributes.fetch(:title),
        slug: attributes.fetch(:slug),
        status: attributes.fetch(:status),
        published_at: attributes[:published_at],
        data: attributes.fetch(:data, { "body" => "Body copy" })
      }
    )
  end
end
