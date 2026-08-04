require "test_helper"

class ImageFieldSaveTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(
      email: "image-save-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    @content_type = @site.content_types.create!(
      name: "Image Save #{SecureRandom.hex(3)}",
      handle: "image_save_#{SecureRandom.hex(4)}",
      blueprint: {
        "fields" => [
          { "handle" => "hero_image", "type" => "image", "label" => "Hero Image" },
          { "handle" => "body", "type" => "textarea", "label" => "Body" }
        ]
      }
    )
    @entry = @content_type.entries.create!(
      site: @site,
      title: "Independent image save",
      slug: "independent-image-save-#{SecureRandom.hex(3)}",
      status: :draft,
      data: { "body" => "Persisted body" }
    )
    @asset = @site.assets.build(alt_text: "Selected image")
    attach_test_png(@asset)
    @asset.save!

    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "saves an entry image without changing other content" do
    patch image_field_cp_content_type_entry_path(@content_type, @entry),
      params: { field_handle: "hero_image", asset_id: @asset.id },
      as: :json

    assert_response :success
    @entry.reload
    assert_equal @asset.id, @entry.data["hero_image"]
    assert_equal "Persisted body", @entry.data["body"]
  end

  test "renders the independent image save control" do
    get edit_cp_content_type_entry_path(@content_type, @entry)

    assert_response :success
    assert_select "[data-plum--image-picker-save-url-value='#{cp_content_type_entry_path(@content_type, @entry)}/image_field']"
    assert_select "button", text: "Save image"
  end

  test "rejects an asset from another site" do
    other_site = Plum::Site.create!(name: "Other image site", skip_defaults: true)
    other_asset = other_site.assets.build
    attach_test_png(other_asset, filename: "other.png")
    other_asset.save!

    patch image_field_cp_content_type_entry_path(@content_type, @entry),
      params: { field_handle: "hero_image", asset_id: other_asset.id },
      as: :json

    assert_response :unprocessable_entity
    assert_nil @entry.reload.data["hero_image"]
  end

  test "removes an entry image without changing other content" do
    @entry.update!(data: @entry.data.merge("hero_image" => @asset.id))

    patch image_field_cp_content_type_entry_path(@content_type, @entry),
      params: { field_handle: "hero_image", asset_id: nil },
      as: :json

    assert_response :success
    @entry.reload
    assert_nil @entry.data["hero_image"]
    assert_equal "Persisted body", @entry.data["body"]
  end
end
