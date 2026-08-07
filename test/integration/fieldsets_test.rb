require "test_helper"

class FieldsetsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(email: "fieldset-admin@example.com", password: "password123", role: :admin)
    @source = @site.content_types.create!(
      name: "SEO Source", handle: "seo_source", blueprint: { "fields" => [
        { "handle" => "seo_title", "type" => "text", "label" => "SEO title" },
        { "handle" => "seo_description", "type" => "textarea", "label" => "SEO description" }
      ] }
    )
    @target = @site.content_types.create!(name: "Pages", handle: "fieldset_pages", blueprint: { "fields" => [ { "handle" => "body", "type" => "rich_text" } ] })
    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "creates a reusable fieldset from a content type" do
    post cp_fieldsets_path, params: { fieldset: { name: "SEO", content_type_id: @source.id } }

    assert_redirected_to cp_fieldsets_path
    fieldset = @site.fieldsets.find_by!(handle: "seo")
    assert_equal %w[seo_title seo_description], fieldset.fields.map { |field| field["handle"] }
  end

  test "applies a fieldset to a blueprint" do
    fieldset = @site.fieldsets.create!(name: "SEO", handle: "seo", fields: @source.fields)

    post apply_fieldset_cp_content_type_path(@target), params: { fieldset_id: fieldset.id }, as: :json

    assert_response :success
    assert_equal %w[body seo_title seo_description], @target.reload.fields.map { |field| field["handle"] }
  end

  test "rejects collisions without partially changing the blueprint" do
    fieldset = @site.fieldsets.create!(name: "Body", handle: "body_fields", fields: [ { "handle" => "body", "type" => "textarea" } ])

    assert_no_changes -> { @target.reload.blueprint } do
      post apply_fieldset_cp_content_type_path(@target), params: { fieldset_id: fieldset.id }, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"], "body"
  end

  test "cannot apply another site's fieldset" do
    other_site = Plum::Site.create!(name: "Other", skip_defaults: true)
    fieldset = other_site.fieldsets.create!(name: "Private", handle: "private", fields: [ { "handle" => "secret", "type" => "text" } ])

    post apply_fieldset_cp_content_type_path(@target), params: { fieldset_id: fieldset.id }, as: :json

    assert_response :not_found
  end
end
