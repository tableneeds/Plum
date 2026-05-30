require "application_system_test_case"

class ContentTypesTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    login_as(@admin)
  end

  test "creating a content type" do
    visit new_cp_content_type_path

    fill_in "Name", with: "Articles"
    click_button "Add Field"

    within "[data-plum--blueprint-target='fields'] [data-plum--blueprint-target='field']:last-child" do
      find("input[data-field='handle']").fill_in with: "body"
      find("select[data-field='type']").select "Rich Text"
      find("input[data-field='label']").fill_in with: "Body Content"
    end

    click_button "Create Content type"

    assert_text "Content type created"
    assert_text "Articles"
  end

  test "creating a relationship field" do
    visit new_cp_content_type_path

    fill_in "Name", with: "Pages"
    click_button "Add Field"

    within "[data-plum--blueprint-target='fields'] [data-plum--blueprint-target='field']:last-child" do
      find("input[data-field='handle']").fill_in with: "featured_post"
      find("select[data-field='type']").select "Relationship"
      find("input[data-field='label']").fill_in with: "Featured Post"
      find("input[data-field='content_type']").fill_in with: "posts"
    end

    click_button "Create Content type"

    assert_text "Content type created"

    click_link "Edit Type"

    within "[data-plum--blueprint-target='fields'] [data-plum--blueprint-target='field']:first-child" do
      assert_equal "relationship", find("select[data-field='type']").value
      assert_equal "posts", find("input[data-field='content_type']").value
    end
  end

  test "editing a content type" do
    content_type = Plum::ContentType.create!(
      name: "Pages",
      handle: "pages",
      blueprint: { "fields" => [] }
    )

    visit edit_cp_content_type_path(content_type)

    fill_in "Name", with: "Landing Pages"
    click_button "Update Content type"

    assert_text "Content type updated"
    assert_text "Landing Pages"
  end

  test "deleting a content type" do
    content_type = Plum::ContentType.create!(
      name: "Temporary",
      handle: "temporary",
      blueprint: { "fields" => [] }
    )

    visit edit_cp_content_type_path(content_type)
    accept_confirm do
      click_button "Delete"
    end

    assert_text "Content type deleted"
  end

  private

  def login_as(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Dashboard" # Wait for login to complete
  end
end
