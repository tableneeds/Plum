require "application_system_test_case"

class PublicPagesTest < ApplicationSystemTestCase
  setup do
    @admin = Plum::User.create!(
      email: "test-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      role: :admin
    )
    Plum::SiteSetting.instance.update!(
      name: "Test Site",
      tagline: "A test site"
    )
    @content_type = Plum::ContentType.create!(
      name: "Blog Posts",
      handle: "posts",
      blueprint: {
        "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" }
        ]
      }
    )
  end

  test "viewing the homepage" do
    visit root_path

    assert_text "Test Site"
    assert_text "A test site"
  end

  test "viewing a published entry" do
    Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Public Post",
      slug: "public-post",
      status: :published,
      published_at: 1.hour.ago,
      data: { "body" => "<p>This is public content.</p>" }
    )

    visit "/public-post"

    assert_text "Public Post"
    assert_text "This is public content."
  end

  test "draft entries return 404" do
    Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Draft Post",
      slug: "draft-post",
      status: :draft,
      data: { "body" => "<p>Draft content.</p>" }
    )

    visit "/draft-post"

    assert_text "page you were looking for"
  end

  test "future published entries return 404" do
    Plum::Entry.create!(
      content_type: @content_type,
      author: @admin,
      title: "Future Post",
      slug: "future-post",
      status: :published,
      published_at: 1.day.from_now,
      data: { "body" => "<p>Future content.</p>" }
    )

    visit "/future-post"

    assert_text "page you were looking for"
  end
end
