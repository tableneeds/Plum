require "test_helper"

class StaticCacheServingTest < ActionDispatch::IntegrationTest
  setup do
    @previous_enabled = Plum.configuration.static_cache_enabled
    @previous_path = Plum.configuration.static_cache_path
    @cache_dir = Rails.root.join("tmp", "static-cache-test-#{SecureRandom.hex(6)}")
    Plum.configuration.static_cache_enabled = true
    Plum.configuration.static_cache_path = @cache_dir

    @site = Plum::Site.first_or_create_standalone!
  end

  teardown do
    Plum.configuration.static_cache_enabled = @previous_enabled
    Plum.configuration.static_cache_path = @previous_path
    FileUtils.rm_rf(@cache_dir)
  end

  test "first hit renders and stores, second hit serves from the cache" do
    get "/"

    assert_response :success
    assert_equal "miss", response.headers["X-Plum-Static-Cache"]
    file = Plum::StaticCache.read(host, "/")
    assert file, "expected the homepage to be cached"

    # Overwrite the cached file to prove the next response comes from disk.
    file.write("<html>from the cache</html>")
    get "/"

    assert_response :success
    assert_equal "hit", response.headers["X-Plum-Static-Cache"]
    assert_equal "<html>from the cache</html>", response.body
    assert_equal "text/html", response.media_type
  end

  test "requests with query strings are never cached or served from cache" do
    get "/?utm_source=x"

    assert_response :success
    assert_nil response.headers["X-Plum-Static-Cache"]
    assert_nil Plum::StaticCache.read(host, "/")
  end

  test "search stays dynamic" do
    get "/search?q=bagels"

    assert_response :success
    assert_nil response.headers["X-Plum-Static-Cache"]
  end

  test "missing pages are not cached" do
    get "/nope-not-here"

    assert_response :not_found
    assert_nil Plum::StaticCache.read(host, "/nope-not-here")
  end

  test "control panel responses are not cached" do
    get "/login"

    assert_response :success
    assert_nil response.headers["X-Plum-Static-Cache"]
    assert_nil Plum::StaticCache.read(host, "/login")
  end

  test "theme assets are cached with their own content type" do
    get "/theme_assets/default/theme.css"

    assert_response :success
    assert_equal "miss", response.headers["X-Plum-Static-Cache"]

    get "/theme_assets/default/theme.css"
    assert_equal "hit", response.headers["X-Plum-Static-Cache"]
    assert_equal "text/css", response.media_type
  end

  test "saving an entry flushes the site cache" do
    get "/"
    assert Plum::StaticCache.read(host, "/")

    @site.entries.find_by!(slug: "home").update!(title: "Updated Home")

    assert_nil Plum::StaticCache.read(host, "/"), "expected entry save to flush the cache"
  end

  test "draft saves keep the cache warm; publishing the draft flushes it" do
    entry = @site.entries.find_by!(slug: "home")
    get "/"
    assert Plum::StaticCache.read(host, "/")

    entry.save_draft!(title: "Drafted", data: { "body" => "<p>Draft only</p>" })
    assert Plum::StaticCache.read(host, "/"), "a draft-only save must not flush the cache"

    entry.publish_draft!
    assert_nil Plum::StaticCache.read(host, "/"), "publishing the draft must flush the cache"
  end

  test "updating a global flushes the site cache" do
    get "/"
    assert Plum::StaticCache.read(host, "/")

    @site.globals.create!(handle: "footer", name: "Footer", data: { "text" => "hi" })

    assert_nil Plum::StaticCache.read(host, "/")
  end

  test "disabled cache leaves requests untouched" do
    Plum.configuration.static_cache_enabled = false

    get "/"

    assert_response :success
    assert_nil response.headers["X-Plum-Static-Cache"]
    assert_nil Plum::StaticCache.read(host, "/")
  end

  private

  def host
    "www.example.com"
  end
end
