require "test_helper"

class StructuredFieldsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(email: "structured@example.com", password: "password123", role: :admin)
    @content_type = @site.content_types.create!(
      name: "Directories",
      handle: "directories",
      blueprint: { "fields" => [
        { "handle" => "tags", "type" => "list" },
        { "handle" => "capacity", "type" => "number", "number_kind" => "integer", "min" => "1" },
        { "handle" => "contact", "type" => "group", "fields" => [
          { "handle" => "name", "type" => "text" },
          { "handle" => "active", "type" => "boolean" },
          { "handle" => "country", "type" => "text", "default" => "US" }
        ] },
        { "handle" => "people", "type" => "repeater", "fields" => [
          { "handle" => "name", "type" => "text" }, { "handle" => "role", "type" => "text" }
        ] }
      ] }
    )
    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "normalizes list group and repeater JSON submissions" do
    post cp_content_type_entries_path(@content_type), params: {
      entry: {
        title: "Company Directory",
        status: "draft",
        data: {
          tags: '[" staff ", "", "leadership"]',
          capacity: "25",
          contact: '{"name":"Ben","active":"true","ignored":"nope"}',
          people: '[{"name":"Ada","role":"Engineer","ignored":"nope"},{"name":"","role":""}]'
        }
      }
    }

    entry = @content_type.entries.find_by!(title: "Company Directory")
    assert_equal [ "staff", "leadership" ], entry.data["tags"]
    assert_equal 25, entry.data["capacity"]
    assert_equal({ "name" => "Ben", "active" => true, "country" => "US" }, entry.data["contact"])
    assert_equal [ { "name" => "Ada", "role" => "Engineer" } ], entry.data["people"]
  end
end
