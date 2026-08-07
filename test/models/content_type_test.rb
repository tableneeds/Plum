require "test_helper"

class ContentTypeTest < ActiveSupport::TestCase
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
  end

  test "accepts every registered field type" do
    fields = Plum::FieldTypeRegistry.handles.map.with_index do |type, index|
      field = { "handle" => "field_#{index}", "type" => type }
      field["fields"] = [ { "handle" => "value", "type" => "text" } ] if %w[group repeater].include?(type)
      field
    end
    content_type = @site.content_types.new(name: "Everything", handle: "everything", blueprint: { "fields" => fields })

    assert content_type.valid?, content_type.errors.full_messages.to_sentence
  end

  test "rejects unknown field types" do
    content_type = @site.content_types.new(
      name: "Broken",
      handle: "broken",
      blueprint: { "fields" => [ { "handle" => "mystery", "type" => "unknown" } ] }
    )

    assert_not content_type.valid?
    assert_includes content_type.errors[:blueprint], 'field mystery has unknown type "unknown"'
  end

  test "rejects invalid field handles" do
    content_type = @site.content_types.new(
      name: "Broken",
      handle: "broken",
      blueprint: { "fields" => [ { "handle" => "Bad Handle", "type" => "text" } ] }
    )

    assert_not content_type.valid?
    assert_includes content_type.errors[:blueprint], 'field handle "Bad Handle" is invalid'
  end

  test "validates nested fields" do
    content_type = @site.content_types.new(
      name: "Team",
      handle: "team",
      blueprint: { "fields" => [
        { "handle" => "people", "type" => "repeater", "fields" => [
          { "handle" => "name", "type" => "text" },
          { "handle" => "photo", "type" => "image" }
        ] }
      ] }
    )

    assert_not content_type.valid?
    assert_includes content_type.errors[:blueprint], 'field people.photo has unsupported nested type "image"'
  end

  test "validates collection and number configuration" do
    content_type = @site.content_types.new(
      name: "Invalid Constraints",
      handle: "invalid_constraints",
      blueprint: { "fields" => [
        { "handle" => "items", "type" => "list", "min_items" => 3, "max_items" => 2 },
        { "handle" => "price", "type" => "number", "min" => "ten", "step" => "0" }
      ] }
    )

    assert_not content_type.valid?
    assert_includes content_type.errors[:blueprint], "field items maximum items must be at least its minimum"
    assert_includes content_type.errors[:blueprint], "field price minimum must be numeric"
    assert_includes content_type.errors[:blueprint], "field price step must be greater than zero"
  end

  test "validates field widths and conditions" do
    content_type = @site.content_types.new(
      name: "Conditional",
      handle: "conditional",
      blueprint: { "fields" => [
        { "handle" => "featured", "type" => "boolean" },
        { "handle" => "dek", "type" => "text", "width" => 13, "condition" => { "field" => "missing", "operator" => "sometimes" } }
      ] }
    )

    assert_not content_type.valid?
    assert_includes content_type.errors[:blueprint], "field dek width must be between 1 and 12"
    assert_includes content_type.errors[:blueprint], "field dek condition references an unknown field"
    assert_includes content_type.errors[:blueprint], "field dek condition has an invalid operator"
  end
end
