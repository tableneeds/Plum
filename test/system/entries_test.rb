require "application_system_test_case"

class EntriesTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    @content_type = Plum::ContentType.create!(
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
    entry = Plum::Entry.create!(
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
    entry = Plum::Entry.create!(
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

  test "rich text field shows editor toolbar" do
    visit new_cp_content_type_entry_path(@content_type)

    assert_selector "lexxy-editor.lexxy-content"
    assert_selector "button[title='Bold']"
    assert_selector "button[title='Italic']"
    assert_selector "input[type='hidden'][name='entry[data][body]']", visible: :hidden
  end

  test "plain text paste creates separate blocks for heading formatting" do
    visit new_cp_content_type_entry_path(@content_type)

    editor = find("lexxy-editor .lexxy-editor__content")
    page.execute_script(<<~JAVASCRIPT, editor.native)
      const editor = arguments[0]
      const clipboard = new DataTransfer()
      clipboard.setData("text/plain", "First section\\n\\nSecond section")
      editor.dispatchEvent(new ClipboardEvent("paste", {
        bubbles: true,
        cancelable: true,
        clipboardData: clipboard
      }))
    JAVASCRIPT

    assert_selector "lexxy-editor p", text: "First section"
    assert_selector "lexxy-editor p", text: "Second section"

    find("lexxy-editor p", text: "First section").click
    find("button[title='Heading']").click

    assert_selector "lexxy-editor h2", text: "First section"
    assert_selector "lexxy-editor p", text: "Second section"
  end

  test "creating an entry with an uploaded image field" do
    image_path = png_fixture_path(filename: "hero.png")
    @content_type.update!(
      blueprint: {
        "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" },
          { "handle" => "hero_image", "type" => "image", "label" => "Hero Image" }
        ]
      }
    )

    visit new_cp_content_type_entry_path(@content_type)

    fill_in "Title", with: "Image Entry"
    fill_rich_text with: "Image body"
    click_button "Choose image"
    attach_file "entry_data_hero_image-upload", image_path, make_visible: true
    assert_selector "[data-plum--image-picker-target='preview'] img"
    select "Published", from: "Status"
    click_button "Save"

    assert_text "Entry created"

    entry = Plum::Entry.find_by!(slug: "image-entry")
    asset = Plum::Asset.find(entry.data["hero_image"])

    assert_equal "Image Entry Hero Image", asset.alt_text

    visit "/image-entry"

    assert_selector "img[alt='Image Entry Hero Image']"
  ensure
    FileUtils.rm_f(image_path) if image_path
  end

  test "creating an entry with a relationship field" do
    related_entry = Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Everything Bagel",
      slug: "everything-bagel",
      status: :draft,
      data: { "body" => "Related body", "excerpt" => "Related excerpt" }
    )
    page_type = Plum::ContentType.create!(
      name: "Pages",
      handle: "pages",
      blueprint: {
        "fields" => [
          {
            "handle" => "featured_post",
            "type" => "relationship",
            "label" => "Featured Post",
            "content_type" => "posts"
          }
        ]
      }
    )

    visit new_cp_content_type_entry_path(page_type)

    fill_in "Title", with: "Homepage"
    select "Everything Bagel (Blog Posts)", from: "Featured Post"
    click_button "Save"

    assert_text "Entry created"
    assert_text "Everything Bagel"

    assert_equal related_entry.id.to_s, find("#entry_data_featured_post").value
  end

  test "markdown content renders on public page" do
    Plum::Entry.create!(
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

  test "creating an entry with Lexxy rich text HTML" do
    visit new_cp_content_type_entry_path(@content_type)

    fill_in "Title", with: "Rich Text Post"

    within "lexxy-editor" do
      find("button[title='Bold']").click
      editor = find(".lexxy-editor__content")
      editor.click
      editor.send_keys("Bold intro")
      find("button[title='Bold']").click
      editor.send_keys(" and plain text.")
    end

    select "Published", from: "Status"
    click_button "Save"

    assert_text "Entry created"

    entry = Plum::Entry.find_by!(slug: "rich-text-post")
    assert_includes entry.data["body"], "<strong>Bold intro</strong>"

    visit "/rich-text-post"
    assert_selector "strong", text: "Bold intro"
    assert_text "and plain text."
  end

  private

  def fill_rich_text(with:)
    editor = find("lexxy-editor .lexxy-editor__content")
    editor.click
    editor.send_keys(with)
  end

  def login_as(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
    assert_current_path cp_root_path
  end
end
