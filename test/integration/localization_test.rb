require "test_helper"

class LocalizationTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @site.update!(settings: { "locales" => [ "en", "es" ], "default_locale" => "en" })
    Plum::SiteSetting.instance(@site).update!(name: "Localized Site", theme_name: "default")
    @pages = @site.content_types.create!(name: "Pages", handle: "localized_pages", blueprint: { "fields" => [ { "handle" => "body", "type" => "rich_text" } ] })
    @english = @pages.entries.create!(site: @site, title: "About", slug: "about", locale: "en", status: :published, published_at: 1.hour.ago, data: { "body" => "English copy" })
    @spanish = @pages.entries.create!(site: @site, origin: @english, title: "Acerca", slug: "about", locale: "es", status: :published, published_at: 1.hour.ago, data: { "body" => "Texto español" })
  end

  test "serves the default locale without a prefix and translations with one" do
    get "/about"
    assert_response :success
    assert_includes response.body, "English copy"

    get "/es/about"
    assert_response :success
    assert_includes response.body, "Texto español"
  end

  test "filters the content API by locale" do
    get api_v1_collection_entries_path(@pages.handle), params: { locale: "es" }

    assert_response :success
    assert_equal [ "Acerca" ], response.parsed_body["data"].map { |entry| entry["title"] }
    assert_equal "/es/about", response.parsed_body.dig("data", 0, "url")
  end

  test "creates a draft translation from the control panel" do
    @spanish.destroy!
    admin = Plum::User.create!(email: "translator@example.com", password: "password123", role: :admin)
    post login_path, params: { email: admin.email, password: "password123" }

    post translate_cp_content_type_entry_path(@pages, @english), params: { locale: "es" }

    translation = @english.translations.find_by!(locale: "es")
    assert_redirected_to edit_cp_content_type_entry_path(@pages, translation)
    assert translation.draft?
    assert_equal "English copy", translation.data["body"]
  end

  test "rejects an unconfigured locale" do
    get "/fr/about"

    assert_response :not_found
  end
end
