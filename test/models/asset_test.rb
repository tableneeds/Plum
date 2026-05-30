require "test_helper"

module Plum
  class AssetTest < ActiveSupport::TestCase
    test "exposes image metadata to liquid" do
      site = Site.create!(name: "Bagel Boy", theme_name: "default")
      asset = site.assets.build(alt_text: "Sesame bagel", caption: "Fresh tray", folder: " menu ")
      attach_test_png(asset, filename: "bagel.png")

      assert asset.save

      liquid = asset.to_liquid
      assert_equal asset.id, liquid["id"]
      assert_equal "Sesame bagel", liquid["alt_text"]
      assert_equal "Fresh tray", liquid["caption"]
      assert_equal "bagel.png", liquid["filename"]
      assert_equal "image/png", liquid["content_type"]
      assert_equal "menu", liquid["folder"]
      assert_includes liquid["url"], "/rails/active_storage/blobs"
    end

    test "rejects non image uploads" do
      site = Site.create!(name: "Bagel Boy", theme_name: "default")
      asset = site.assets.build
      asset.file.attach(
        io: StringIO.new("not image"),
        filename: "notes.txt",
        content_type: "text/plain"
      )

      refute asset.valid?
      assert_includes asset.errors[:file], "must be an image"
    end
  end
end
