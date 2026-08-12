require "application_system_test_case"

class WritingModeBodyTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "writer-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    @content_type = Plum::ContentType.create!(
      name: "Posts",
      handle: "posts",
      blueprint: { "fields" => [ { "handle" => "body", "type" => "rich_text", "label" => "Body" } ] }
    )
    @entry = Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Body test",
      slug: "body-test",
      status: :draft,
      data: { "body" => "<p>Original</p>" }
    )
    login_as(@admin)
  end

  test "typing in the body and clicking save persists the body" do
    visit write_cp_content_type_entry_path(@content_type, @entry)

    editor = find("lexxy-editor [contenteditable]")
    editor.click
    editor.send_keys(" plus new words")

    click_button "Save"
    assert_text(/Saved at/i, wait: 5)

    body = @entry.reload.data["body"]
    assert_includes body, "plus new words", "body edits were not persisted (stored body: #{body.inspect})"
  end

  test "body autosave fires from typing alone" do
    visit write_cp_content_type_entry_path(@content_type, @entry)

    editor = find("lexxy-editor [contenteditable]")
    editor.click
    editor.send_keys(" autosaved words")

    assert_text(/Saved at/i, wait: 8)
    assert_includes @entry.reload.data["body"], "autosaved words"
  end

  test "published entry body edits land in the draft and survive round trips" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    visit write_cp_content_type_entry_path(@content_type, @entry)

    editor = find("lexxy-editor [contenteditable]")
    editor.click
    editor.send_keys(" draft words")

    click_button "Save draft"
    assert_text(/Draft saved at/i, wait: 5)

    @entry.reload
    assert_includes @entry.draft_field_value("body").to_s, "draft words"
    assert_equal "<p>Original</p>", @entry.data["body"]

    # Reopening writing mode shows the draft, not the live version.
    visit write_cp_content_type_entry_path(@content_type, @entry)
    assert_text "draft words"

    # And so does the regular editor ("back to the editor" must show my words).
    visit edit_cp_content_type_entry_path(@content_type, @entry)
    assert_text "draft words"
    assert_text "unpublished draft changes"
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
