require "test_helper"

class CustomFieldTypesTest < ActionDispatch::IntegrationTest
  setup do
    Plum::FieldTypeRegistry.reset_custom!
    Plum.register_field_type(
      handle: :postal_code,
      label: "Postal Code",
      partial: "plum/cp/custom_fields/input",
      normalizer: ->(value:, **) { value.to_s.upcase.delete(" ") },
      validator: ->(value:, **) { "must be five digits" unless value.to_s.match?(/\A\d{5}\z/) },
      expander: ->(value:, **) { { "formatted" => value.to_s, "region" => "US" } }
    )
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(email: "custom-fields@example.com", password: "password123", role: :admin)
    @locations = @site.content_types.create!(
      name: "Locations", handle: "locations", blueprint: { "fields" => [
        { "handle" => "postal_code", "type" => "postal_code", "label" => "ZIP" }
      ] }
    )
    post login_path, params: { email: @admin.email, password: "password123" }
  end

  teardown do
    Plum::FieldTypeRegistry.reset_custom!
  end

  test "renders and normalizes a registered field type" do
    get new_cp_content_type_entry_path(@locations)
    assert_response :success
    assert_select "input[name='entry[data][postal_code]']"

    post cp_content_type_entries_path(@locations), params: { entry: { title: "Shop", status: "draft", data: { postal_code: " 12345 " } } }

    assert_redirected_to edit_cp_content_type_entry_path(@locations, @locations.entries.last)
    assert_equal "12345", @locations.entries.last.data["postal_code"]
  end

  test "runs custom validation" do
    post cp_content_type_entries_path(@locations), params: { entry: { title: "Shop", status: "draft", data: { postal_code: "ABC" } } }

    assert_response :unprocessable_entity
    assert_includes response.body, "ZIP must be five digits"
  end

  test "expands custom values for Liquid and the API" do
    entry = @locations.entries.create!(site: @site, title: "Shop", status: :published, published_at: 1.hour.ago, data: { "postal_code" => "12345" })

    expanded = Plum::FieldExpander.new(site: @site).expand(values: entry.data, fields: @locations.fields)

    assert_equal({ "formatted" => "12345", "region" => "US" }, expanded["postal_code"])
  end
end
