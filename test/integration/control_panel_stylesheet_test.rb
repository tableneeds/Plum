require "test_helper"

class ControlPanelStylesheetTest < ActiveSupport::TestCase
  test "packaged stylesheet contains blueprint layout utilities" do
    stylesheet = Rails.root.join("app/assets/stylesheets/plum/control_panel.css").read

    assert_includes stylesheet, ".col-span-full"
    assert_includes stylesheet, ".sm\\:grid-cols-3"
    assert_includes stylesheet, ".plum-blueprint-field"
  end
end
