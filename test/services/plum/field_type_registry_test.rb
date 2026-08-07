require "test_helper"

class Plum::FieldTypeRegistryTest < ActiveSupport::TestCase
  test "contains every field type exposed by the entry editor" do
    assert_equal %w[
      text textarea rich_text number boolean date select radio button_group checkboxes color url
      taxonomy image images relationship blocks list group repeater section
    ], Plum::FieldTypeRegistry.handles
  end

  test "provides labels for blueprint controls" do
    assert_includes Plum::FieldTypeRegistry.options, [ "Rich Text", "rich_text" ]
  end

  test "finds definitions by string-compatible handle" do
    assert_equal "Image", Plum::FieldTypeRegistry.find(:image).label
    assert_not Plum::FieldTypeRegistry.include?(:unknown)
  end
end
