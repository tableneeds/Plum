require "test_helper"

module Plum
  class ContentSourceRegistryTest < ActiveSupport::TestCase
    FakeController = Struct.new(:request, :params, :session) do
      def current_user
        "admin@example.com"
      end
    end

    Adapter = Class.new do
      def initialize(context)
        @context = context
      end

      def to_liquid
        {
          "site_name" => @context.site.name,
          "user" => @context.current_user
        }
      end
    end

    LazyAdapter = Class.new(Adapter)

    test "resolves adapter class names lazily" do
      registry = ContentSourceRegistry.new
      registry.register(:menu, "Plum::ContentSourceRegistryTest::LazyAdapter")

      context = registry.to_liquid_context(controller: fake_controller, site: fake_site)

      assert_equal "Bagel Boy", context.dig("menu", "site_name")
      assert_equal "admin@example.com", context.dig("menu", "user")
    end

    test "resolves block sources with a content source context" do
      registry = ContentSourceRegistry.new
      registry.register(:restaurant) do |context|
        {
          "name" => context.site.name,
          "path" => context.request.path
        }
      end

      context = registry.to_liquid_context(controller: fake_controller, site: fake_site)

      assert_equal [ "restaurant" ], registry.handles
      assert_equal "Bagel Boy", context.dig("restaurant", "name")
      assert_equal "/menu", context.dig("restaurant", "path")
    end

    test "resolves adapter classes with a content source context" do
      registry = ContentSourceRegistry.new
      registry.register(:menu, Adapter)

      context = registry.to_liquid_context(controller: fake_controller, site: fake_site)

      assert_equal "Bagel Boy", context.dig("menu", "site_name")
      assert_equal "admin@example.com", context.dig("menu", "user")
    end

    test "rejects missing sources" do
      error = assert_raises(ArgumentError) { ContentSourceRegistry.new.register(:menu) }

      assert_equal "Content source is required", error.message
    end

    test "rejects reserved handles" do
      error = assert_raises(ArgumentError) do
        ContentSourceRegistry.new.register(:entries, ->(_context) { [] })
      end

      assert_equal "`entries` is reserved by Plum's Liquid context", error.message
    end

    private

    def fake_controller
      request = ActionDispatch::TestRequest.create
      request.path = "/menu"
      FakeController.new(request, {}, {})
    end

    def fake_site
      Plum::Site.new(name: "Bagel Boy", theme_name: "default")
    end
  end
end
