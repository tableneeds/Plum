require "test_helper"

class ControllerAssetPathTest < ActiveSupport::TestCase
  test "engine controllers resolve beneath the plum importmap namespace" do
    controller_root = Plum::Engine.root.join("app/javascript/controllers").to_s
    asset_paths = Rails.application.config.assets.paths.map(&:to_s)

    assert_includes asset_paths, controller_root
    assert Pathname(controller_root).join("plum/blueprint_controller.js").file?
    assert Pathname(controller_root).join("plum/image_picker_controller.js").file?
    refute_includes asset_paths, File.join(controller_root, "plum")
  end
end
