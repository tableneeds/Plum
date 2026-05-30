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

    BaseAdapter = Class.new(ContentSource) do
      def to_liquid
        {
          name: site.name,
          owner: owner
        }
      end
    end

    MenuItem = Struct.new(:name, :price) do
      def to_liquid
        {
          name: name,
          price: price
        }
      end
    end

    test "resolves adapter class names lazily" do
      registry = ContentSourceRegistry.new
      registry.register(:menu, "Plum::ContentSourceRegistryTest::LazyAdapter")

      context = registry.to_liquid_context(controller: fake_controller, site: fake_site)

      assert_equal "Bagel Boy", context.dig("menu", "site_name")
      assert_equal "admin@example.com", context.dig("menu", "user")
    end

    test "resolves base content source adapters" do
      registry = ContentSourceRegistry.new
      registry.register(:restaurant, BaseAdapter)

      context = registry.to_liquid_context(controller: fake_controller, site: fake_site)

      assert_equal "Bagel Boy", context.dig("restaurant", "name")
      assert_nil context.dig("restaurant", "owner")
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

    test "normalizes liquid output to string-keyed hashes" do
      registry = ContentSourceRegistry.new
      registry.register(:menu) do
        {
          items: [
            MenuItem.new("Sesame Bagel", "$3.50")
          ],
          featured: true
        }
      end

      context = registry.to_liquid_context(controller: fake_controller, site: fake_site)

      assert_equal true, context.dig("menu", "featured")
      assert_equal "Sesame Bagel", context.dig("menu", "items", 0, "name")
      assert_equal "$3.50", context.dig("menu", "items", 0, "price")
    end

    test "rejects missing sources" do
      error = assert_raises(ArgumentError) { ContentSourceRegistry.new.register(:menu) }

      assert_equal "Content source is required", error.message
    end

    test "rejects invalid handles" do
      error = assert_raises(ArgumentError) do
        ContentSourceRegistry.new.register(:"menu-items", ->(_context) { [] })
      end

      assert_equal "Content source handle must use lowercase letters, numbers, and underscores", error.message
    end

    test "rejects reserved handles" do
      error = assert_raises(ArgumentError) do
        ContentSourceRegistry.new.register(:entries, ->(_context) { [] })
      end

      assert_equal "`entries` is reserved by Plum's Liquid context", error.message
    end

    test "raises helpful errors for missing adapter constants" do
      registry = ContentSourceRegistry.new
      registry.register(:menu, "Missing::MenuAdapter")

      error = assert_raises(ContentSourceError) do
        registry.to_liquid_context(controller: fake_controller, site: fake_site)
      end

      assert_equal "Content source adapter `Missing::MenuAdapter` could not be found", error.message
    end

    test "raises helpful errors for non liquid safe values" do
      registry = ContentSourceRegistry.new
      registry.register(:menu, ->(_context) { Object.new })

      error = assert_raises(ContentSourceError) do
        registry.to_liquid_context(controller: fake_controller, site: fake_site)
      end

      assert_match "Object is not Liquid-safe", error.message
    end

    test "raises helpful errors for adapters without to_liquid implementations" do
      registry = ContentSourceRegistry.new
      registry.register(:menu, ContentSource)

      error = assert_raises(ContentSourceError) do
        registry.to_liquid_context(controller: fake_controller, site: fake_site)
      end

      assert_equal "Plum::ContentSource must implement #to_liquid", error.message
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
