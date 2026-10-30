require "application_system_test_case"

class CommentsSystemTest < ApplicationSystemTestCase
  setup do
    @previous_configuration = Plum.configuration
    Plum.instance_variable_set(:@configuration, Plum::Configuration.new)
    @site = Plum::Site.first!
    @reader = Plum::User.create!(email: "discussion-reader@example.com", password: "password123", role: :viewer)
    @moderator = Plum::User.create!(email: "discussion-moderator@example.com", password: "password123", role: :admin)
    @type = @site.content_types.create!(name: "Lessons", handle: "lessons", comments_enabled: true, blueprint: { "fields" => [] })
    @entry = @type.entries.create!(site: @site, title: "Learning together", slug: "learning", status: :published, published_at: 1.day.ago)
    Plum.configuration.current_site_resolver = ->(_) { @site }
    Plum.configuration.current_user_resolver = ->(_) { @moderator }
    Plum.configuration.comments.enabled = true
    Plum.configuration.comments.commenter_resolver = ->(_) { @reader }
    Plum.configuration.comments.author_name_resolver = ->(_) { "Church reader" }
  end

  teardown do
    Plum.instance_variable_set(:@configuration, @previous_configuration)
  end

  test "reader posts moderator approves and closes a discussion" do
    visit discussion_path(handle: "entries", subject_id: @entry.id)
    fill_in "Your comment", with: "How can I learn more about grace?"
    click_button "Send comment"
    assert_text "Your comment has been received"
    assert_no_text "How can I learn more about grace?"
    visit cp_comments_path
    assert_text "How can I learn more about grace?"
    click_button "Approve"
    assert_text "Comment updated"
    visit discussion_path(handle: "entries", subject_id: @entry.id)
    assert_text "How can I learn more about grace?"
    assert_text "Church reader"
    visit cp_comments_path(status: "approved")
    click_button "Close discussion"
    assert_text "Discussion updated"
    visit discussion_path(handle: "entries", subject_id: @entry.id)
    assert_text "This discussion is closed"
    assert_no_button "Send comment"
    assert_text "How can I learn more about grace?"
  end
end
