require "test_helper"

module Plum
  class CpAssetsJsonTest < ActionDispatch::IntegrationTest
    setup do
      @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      Plum::SiteSetting.instance(@site).update!(name: "Test Site", theme_name: "default")
      Plum::User.create!(email: "admin@example.com", password: "password123", role: :admin)
      post login_path, params: { email: "admin@example.com", password: "password123" }
    end

    test "index returns the site's assets as JSON" do
      asset = @site.assets.build(alt_text: "A bagel", focal_x: 20, focal_y: 80)
      attach_test_png(asset)
      asset.save!

      get cp_assets_path(format: :json)

      assert_response :success
      body = JSON.parse(response.body)
      record = body.find { |a| a["id"] == asset.id }
      assert record, "expected the uploaded asset in the JSON list"
      assert_equal "A bagel", record["alt_text"]
      assert_equal "20% 80%", record["object_position"]
      assert record["url"].present?
    end

    test "create accepts a JSON upload and returns the asset" do
      assert_difference -> { @site.assets.count }, 1 do
        post cp_assets_path(format: :json), params: {
          asset: { file: Rack::Test::UploadedFile.new(png_fixture_path, "image/png") }
        }
      end

      assert_response :created
      record = JSON.parse(response.body)
      assert record["id"].present?
      assert record["url"].present?
    end

    test "create returns errors as JSON for a non-image" do
      file = Rails.root.join("tmp", "#{SecureRandom.hex(4)}.txt")
      File.write(file, "not an image")

      post cp_assets_path(format: :json), params: {
        asset: { file: Rack::Test::UploadedFile.new(file, "text/plain") }
      }

      assert_response :unprocessable_entity
      assert JSON.parse(response.body)["errors"].present?
    end
  end
end
