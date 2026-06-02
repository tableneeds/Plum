require "test_helper"

# Regression: a nav item (or relationship) pointing at a blocks-driven entry
# must not infinitely recurse (nav -> entry -> blocks -> shared assigns -> nav).
class NavEntryBlocksTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    Plum::SiteSetting.instance(@site).update!(name: "Bagel Boy", theme_name: "default")

    type = @site.content_types.create!(
      name: "Pages", handle: "pages",
      blueprint: { "fields" => [ { "handle" => "sections", "type" => "blocks" } ] }
    )
    @page = @site.entries.create!(
      content_type: type, title: "Catering", slug: "catering",
      status: :published, published_at: Time.current,
      data: { "sections" => [ { "id" => "1", "type" => "rich_text", "fields" => { "body" => "Book us." } } ] }
    )

    menu = @site.nav_menus.create!(name: "Main", handle: "main")
    menu.nav_items.create!(site: @site, label: "Catering", entry: @page, position: 1)
  end

  test "a page renders when the nav links to a blocks-driven entry" do
    get "/catering"

    assert_response :success
    assert_includes response.body, "Book us."
  end
end
