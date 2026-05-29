require "application_system_test_case"

class EntriesTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(
      email: "test@example.com",
      password: "password123",
      role: :admin
    )
    @content_type = ContentType.create!(
      name: "Blog Posts",
      handle: "posts",
      blueprint: {
        "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" },
          { "handle" => "excerpt", "type" => "textarea", "label" => "Excerpt" }
        ]
      }
    )
    login_as(@admin)
  end

  test "creating an entry with basic fields" do
    visit new_cp_content_type_entry_path(@content_type)

    fill_in "Title", with: "My First Post"
    select "Published", from: "Status"

    click_button "Save"

    assert_text "Entry created"
    assert_text "My First Post"
  end

  test "editing an entry" do
    entry = Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Original Title",
      slug: "original-title",
      status: :draft,
      data: { "body" => "Some content", "excerpt" => "Excerpt" }
    )

    visit edit_cp_content_type_entry_path(@content_type, entry)

    fill_in "Title", with: "Updated Title"
    click_button "Save"

    assert_text "Entry updated"
    assert_text "Updated Title"
  end

  test "deleting an entry" do
    entry = Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "To Be Deleted",
      slug: "to-be-deleted",
      status: :draft,
      data: {}
    )

    visit edit_cp_content_type_entry_path(@content_type, entry)

    accept_confirm "Are you sure you want to delete this entry?" do
      click_button "Delete Entry"
    end

    assert_current_path cp_content_type_entries_path(@content_type)
    assert_text "Entry deleted"
  end

  test "rich text field shows markdown hint" do
    visit new_cp_content_type_entry_path(@content_type)

    assert_text "Supports Markdown"
    assert_text "**bold**"
  end

  test "markdown content renders on public page" do
    Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Markdown Test",
      slug: "markdown-test",
      status: :published,
      published_at: 1.hour.ago,
      data: { "body" => "This is **bold** text." }
    )

    visit "/markdown-test"

    # The markdown should be converted to HTML
    assert_selector "strong", text: "bold"
  end

  private

  def login_as(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_text "Dashboard"
  end
end
