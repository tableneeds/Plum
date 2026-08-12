require "test_helper"

class WritingModeTest < ActionDispatch::IntegrationTest
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @admin = Plum::User.create!(email: "writer@example.com", password: "password123", role: :admin)
    @posts = @site.content_types.create!(
      name: "Posts",
      handle: "writing_posts",
      blueprint: { "fields" => [
        { "handle" => "excerpt", "type" => "textarea", "label" => "Excerpt" },
        { "handle" => "body", "type" => "rich_text", "label" => "Body" }
      ] }
    )
    @entry = @posts.entries.create!(
      site: @site, title: "Draft post", slug: "draft-post", status: :draft,
      data: { "excerpt" => "A teaser", "body" => "<p>Started</p>" }
    )
    post login_path, params: { email: @admin.email, password: "password123" }
  end

  test "renders the writing surface for the first rich text field" do
    get write_cp_content_type_entry_path(@posts, @entry)

    assert_response :success
    assert_includes response.body, "plum-write-title"
    assert_includes response.body, "lexxy-editor"
    assert_includes response.body, "entry[data][body]"
    refute_includes response.body, "entry[data][excerpt]"
  end

  test "redirects to the editor when the content type has no rich text field" do
    plain = @site.content_types.create!(
      name: "Plain", handle: "writing_plain",
      blueprint: { "fields" => [ { "handle" => "summary", "type" => "text" } ] }
    )
    entry = plain.entries.create!(site: @site, title: "Plain", slug: "writing-plain", status: :draft)

    get write_cp_content_type_entry_path(plain, entry)

    assert_redirected_to edit_cp_content_type_entry_path(plain, entry)
  end

  test "write mode saves merge into existing data instead of replacing it" do
    patch cp_content_type_entry_path(@posts, @entry), params: {
      entry: { write_mode: "1", title: "Better title", data: { body: "<p>More words</p>" } }
    }

    assert_redirected_to write_cp_content_type_entry_path(@posts, @entry)
    @entry.reload
    assert_equal "Better title", @entry.title
    assert_equal "<p>More words</p>", @entry.data["body"]
    assert_equal "A teaser", @entry.data["excerpt"], "expected unsubmitted fields to survive a write-mode save"
  end

  test "autosave returns JSON and does not wipe other fields" do
    patch cp_content_type_entry_path(@posts, @entry),
          params: { entry: { write_mode: "1", title: "Draft post", data: { body: "<p>Autosaved</p>" } } },
          headers: { "Accept" => "application/json" }

    assert_response :success
    assert JSON.parse(response.body)["saved"]
    @entry.reload
    assert_equal "<p>Autosaved</p>", @entry.data["body"]
    assert_equal "A teaser", @entry.data["excerpt"]
  end

  test "autosave validation failures return errors as JSON" do
    patch cp_content_type_entry_path(@posts, @entry),
          params: { entry: { write_mode: "1", title: "", data: { body: "<p>x</p>" } } },
          headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal false, body["saved"]
    assert body["errors"].any? { |message| message.include?("Title") }
  end

  test "identical autosaves do not stack duplicate revisions" do
    2.times do
      patch cp_content_type_entry_path(@posts, @entry),
            params: { entry: { write_mode: "1", title: "Draft post", data: { body: "<p>Same</p>" } } },
            headers: { "Accept" => "application/json" }
      assert_response :success
    end

    assert_equal 1, @entry.revisions.count
  end

  test "write-mode saves on a published entry become a draft and leave the live version alone" do
    @entry.update!(status: :published, published_at: 1.hour.ago)

    patch cp_content_type_entry_path(@posts, @entry),
          params: { entry: { write_mode: "1", title: "Reworked title", data: { body: "<p>Reworked</p>" } } },
          headers: { "Accept" => "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["saved"]
    assert body["draft"]

    @entry.reload
    assert_equal "Draft post", @entry.title, "live title must not change"
    assert_equal "<p>Started</p>", @entry.data["body"], "live body must not change"
    assert @entry.has_draft?
    assert_equal "Reworked title", @entry.draft_title
    assert_equal "<p>Reworked</p>", @entry.draft_field_value("body")
    assert_equal "A teaser", @entry.draft_field_value("excerpt"), "draft falls back to live data for untouched fields"
  end

  test "consecutive draft saves merge instead of replacing" do
    @entry.update!(status: :published, published_at: 1.hour.ago)

    patch cp_content_type_entry_path(@posts, @entry),
          params: { entry: { write_mode: "1", title: "First pass", data: { body: "<p>One</p>" } } },
          headers: { "Accept" => "application/json" }
    patch cp_content_type_entry_path(@posts, @entry),
          params: { entry: { write_mode: "1", title: "Second pass", data: { body: "<p>Two</p>" } } },
          headers: { "Accept" => "application/json" }

    @entry.reload
    assert_equal "Second pass", @entry.draft_title
    assert_equal "<p>Two</p>", @entry.draft_field_value("body")
    assert_equal "A teaser", @entry.draft_field_value("excerpt")
  end

  test "publishing a draft applies it, clears it, and records a revision" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    @entry.save_draft!(title: "Ready now", data: { "body" => "<p>Final</p>" })

    assert_difference -> { @entry.revisions.count }, 1 do
      post publish_draft_cp_content_type_entry_path(@posts, @entry)
    end

    @entry.reload
    assert_equal "Ready now", @entry.title
    assert_equal "<p>Final</p>", @entry.data["body"]
    assert_equal "A teaser", @entry.data["excerpt"]
    assert_not @entry.has_draft?
  end

  test "discarding a draft keeps the live version" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    @entry.save_draft!(title: "Scrapped", data: { "body" => "<p>Scrapped</p>" })

    delete discard_draft_cp_content_type_entry_path(@posts, @entry)

    @entry.reload
    assert_not @entry.has_draft?
    assert_equal "Draft post", @entry.title
    assert_equal "<p>Started</p>", @entry.data["body"]
  end

  test "the writing surface shows draft content when a draft exists" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    @entry.save_draft!(title: "Draft headline", data: { "body" => "<p>Draft body</p>" })

    get write_cp_content_type_entry_path(@posts, @entry)

    assert_response :success
    assert_includes response.body, "Draft headline"
    assert_includes response.body, "Draft body"
    assert_includes response.body, "Publish changes"
  end

  test "the edit form shows draft content and a full save publishes and clears it" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    @entry.save_draft!(title: "Draft headline", data: { "body" => "<p>Draft body</p>" })

    get edit_cp_content_type_entry_path(@posts, @entry)

    assert_response :success
    assert_includes response.body, "Draft headline"
    assert_includes response.body, "Draft body"
    assert_includes response.body, "unpublished draft changes"

    patch cp_content_type_entry_path(@posts, @entry), params: {
      entry: { title: "Draft headline", slug: @entry.slug, status: "published",
               data: { excerpt: "A teaser", body: "<p>Draft body</p>" } }
    }

    @entry.reload
    assert_equal "Draft headline", @entry.title
    assert_equal "<p>Draft body</p>", @entry.data["body"]
    assert_not @entry.has_draft?, "a full-form save publishes what was shown, so the draft should clear"
  end

  test "the diff page reviews draft changes against the live version" do
    @entry.update!(status: :published, published_at: 1.hour.ago)
    @entry.save_draft!(title: "Draft post", data: { "body" => "<p>Started anew</p>" })

    get diff_cp_content_type_entry_path(@posts, @entry)

    assert_response :success
    assert_includes response.body, "Review draft changes"
    assert_includes response.body, "<ins", "expected inserted text markup"
    assert_includes response.body, "anew"
  end

  test "the diff page redirects when there is no draft" do
    get diff_cp_content_type_entry_path(@posts, @entry)

    assert_redirected_to edit_cp_content_type_entry_path(@posts, @entry)
  end

  test "regular full-form saves still replace data wholesale" do
    patch cp_content_type_entry_path(@posts, @entry), params: {
      entry: { title: "Full save", slug: @entry.slug, status: "draft", data: { excerpt: "New teaser", body: "<p>Full</p>" } }
    }

    assert_redirected_to edit_cp_content_type_entry_path(@posts, @entry)
    @entry.reload
    assert_equal "New teaser", @entry.data["excerpt"]
  end
end
