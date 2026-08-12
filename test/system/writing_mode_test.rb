require "application_system_test_case"

class WritingModeSystemTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "writer-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    @content_type = Plum::ContentType.create!(
      name: "Posts",
      handle: "posts",
      blueprint: {
        "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" },
          { "handle" => "excerpt", "type" => "textarea", "label" => "Excerpt" }
        ]
      }
    )
    @entry = Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Draft post",
      slug: "draft-post",
      status: :draft,
      data: { "body" => "<p>Started</p>", "excerpt" => "Teaser" }
    )
    login_as(@admin)
  end

  test "manual save persists the title from the writing surface" do
    visit write_cp_content_type_entry_path(@content_type, @entry)

    fill_in placeholder: "Untitled", with: "A better title"
    assert_selector ".plum-write-save-state[data-state='dirty']", wait: 2

    click_button "Save"

    assert_text(/Saved at/i, wait: 5)
    assert_selector ".plum-write-save-state[data-state='saved']"
    assert_equal "A better title", @entry.reload.title
    assert_equal "Teaser", @entry.data["excerpt"]
  end

  test "typing triggers an autosave" do
    visit write_cp_content_type_entry_path(@content_type, @entry)

    fill_in placeholder: "Untitled", with: "Autosaved title"

    assert_text(/Saved at/i, wait: 8)
    assert_equal "Autosaved title", @entry.reload.title
  end

  test "editing a published entry drafts first, then publishes on demand" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    visit write_cp_content_type_entry_path(@content_type, @entry)

    fill_in placeholder: "Untitled", with: "Reworked live post"

    assert_text(/Draft saved at/i, wait: 8)
    assert_equal "Draft post", @entry.reload.title, "live title must not change on autosave"
    assert_equal "Reworked live post", @entry.draft_title

    click_button "Publish changes"

    assert_text(/Published at/i, wait: 8)
    @entry.reload
    assert_equal "Reworked live post", @entry.title
    assert_not @entry.has_draft?
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
