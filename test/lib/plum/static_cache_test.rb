require "test_helper"

module Plum
  class StaticCacheTest < ActiveSupport::TestCase
    setup do
      @previous_enabled = Plum.configuration.static_cache_enabled
      @previous_path = Plum.configuration.static_cache_path
      @cache_dir = Rails.root.join("tmp", "static-cache-test-#{SecureRandom.hex(6)}")
      Plum.configuration.static_cache_enabled = true
      Plum.configuration.static_cache_path = @cache_dir
    end

    teardown do
      Plum.configuration.static_cache_enabled = @previous_enabled
      Plum.configuration.static_cache_path = @previous_path
      FileUtils.rm_rf(@cache_dir)
    end

    test "stores pages as host-scoped index.html files" do
      file = StaticCache.store("example.com", "/about", "<html>About</html>")

      assert_equal @cache_dir.join("example.com", "about", "index.html").to_s, file.to_s
      assert_equal "<html>About</html>", file.read
      assert_equal file.to_s, StaticCache.read("example.com", "/about").to_s
    end

    test "normalizes the root path and trailing slashes" do
      StaticCache.store("example.com", "/", "home")

      assert StaticCache.read("example.com", "/")
      assert_equal "home", StaticCache.read("example.com", "/").read
    end

    test "stores paths with extensions verbatim for theme assets" do
      file = StaticCache.store("example.com", "/theme_assets/default/site.css", "body{}")

      assert_equal @cache_dir.join("example.com", "theme_assets/default/site.css").to_s, file.to_s
      assert_equal "text/css", StaticCache.content_type_for(file)
    end

    test "rejects path traversal" do
      assert_nil StaticCache.file_path("example.com", "/../../etc/passwd")
      assert_nil StaticCache.file_path("example.com", "/%2e%2e/secret")
      assert_nil StaticCache.read("example.com", "/../outside")
    end

    test "sanitizes hostile host names" do
      file = StaticCache.store("../evil", "/page", "x")

      assert file.to_s.start_with?(@cache_dir.to_s), "expected #{file} to stay inside the cache root"
    end

    test "flush_site! removes only that site's domain directories" do
      site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      site.update!(domain: "bagels.example")
      StaticCache.store("bagels.example", "/", "a")
      StaticCache.store("www.bagels.example", "/", "b")
      StaticCache.store("other.example", "/", "c")

      StaticCache.flush_site!(site)

      assert_nil StaticCache.read("bagels.example", "/")
      assert_nil StaticCache.read("www.bagels.example", "/")
      assert StaticCache.read("other.example", "/")
    end

    test "flush_site! without a domain flushes everything" do
      site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      site.update!(domain: nil)
      StaticCache.store("anything.example", "/", "a")

      StaticCache.flush_site!(site)

      assert_nil StaticCache.read("anything.example", "/")
    end

    test "enabled? follows the configuration override" do
      Plum.configuration.static_cache_enabled = false
      assert_not StaticCache.enabled?

      Plum.configuration.static_cache_enabled = true
      assert StaticCache.enabled?
    end
  end
end
