require "test_helper"

class EntryRevisionsTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(email: "revision-admin@example.com", password: "password123", role: :admin)
    @pages = @site.content_types.create!(
      name: "Pages",
      handle: "revision_pages",
      blueprint: { "fields" => [ { "handle" => "body", "type" => "textarea" } ] }
    )
    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "records attributed snapshots after control panel saves" do
    post cp_content_type_entries_path(@pages), params: {
      entry: { title: "History", status: "draft", data: { body: "First" } }
    }
    entry = @pages.entries.find_by!(slug: "history")

    patch cp_content_type_entry_path(@pages, entry), params: {
      entry: { title: "History revised", slug: entry.slug, status: "draft", data: { body: "Second" } }
    }

    assert_equal 2, entry.revisions.count
    assert_equal [ "First", "Second" ], entry.revisions.order(:created_at).map { |revision| revision.snapshot.dig("data", "body") }
    assert_equal @admin.email, entry.revisions.last.editor_label
  end

  test "restores a revision while preserving the replaced version" do
    entry = @pages.entries.create!(site: @site, author: @admin, title: "History", status: :draft, data: { "body" => "First" })
    old_revision = entry.record_revision!(editor: @admin)
    entry.update!(data: { "body" => "Second" })
    entry.record_revision!(editor: @admin)

    post restore_cp_content_type_entry_revision_path(@pages, entry, old_revision)

    assert_redirected_to edit_cp_content_type_entry_path(@pages, entry)
    assert_equal "First", entry.reload.data["body"]
    assert_equal 3, entry.revisions.count
    assert_equal "First", entry.revisions.order(:created_at).last.snapshot.dig("data", "body")
  end

  test "does not expose another site's revisions" do
    other_site = Plum::Site.create!(name: "Other", skip_defaults: true)
    other_type = other_site.content_types.create!(name: "Pages", handle: "pages", blueprint: { "fields" => [] })
    other_entry = other_type.entries.create!(site: other_site, title: "Private", status: :draft, data: {})
    revision = other_entry.record_revision!(editor: @admin)

    get cp_content_type_entry_revisions_path(@pages, revision.entry_id)

    assert_response :not_found
  end
end
