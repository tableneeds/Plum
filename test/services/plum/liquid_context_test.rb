require "test_helper"

module Plum
  class LiquidContextTest < ActiveSupport::TestCase
    setup do
      Plum.configuration.content_sources.clear
    end

    teardown do
      Plum.configuration.content_sources.clear
    end

    test "adds registered content sources to the Liquid context" do
      site = Plum::Site.create!(name: "Bagel Boy", theme_name: "default")
      controller = fake_controller

      Plum.register_content_source(:restaurant) do |context|
        {
          "name" => context.site.name,
          "request_path" => context.request.path
        }
      end

      context = LiquidContext.new(controller: controller, site: site).to_h

      assert_equal "Bagel Boy", context.dig("restaurant", "name")
      assert_equal "/from-host", context.dig("restaurant", "request_path")
    end

    private

    def fake_controller
      request = ActionDispatch::TestRequest.create
      request.path = "/from-host"

      Struct.new(:request) do
        def params
          {}
        end

        def session
          {}
        end
      end.new(request)
    end
  end
end
