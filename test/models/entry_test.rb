require "test_helper"

class EntryTest < ActiveSupport::TestCase
  setup do
    @author = User.create!(
      email: "author@example.com",
      password: "password123",
      role: :admin
    )
    @posts = ContentType.create!(
      name: "Blog Posts",
      handle: "posts",
      blueprint: { "fields" => [] }
    )
  end

  test "status enum matches the brief" do
    assert_equal({ "draft" => 0, "published" => 1, "scheduled" => 2 }, Entry.statuses)
  end

  test "published entries default published_at to now" do
    entry = create_entry("Published Now", :published, nil)

    assert entry.published_at.present?
  end

  test "live scope includes only published entries whose publish time has passed" do
    live = create_entry("Live", :published, 1.hour.ago)
    create_entry("Draft", :draft, 1.hour.ago)
    create_entry("Future", :published, 1.hour.from_now)
    create_entry("Scheduled", :scheduled, 1.hour.ago)

    assert_equal [ live ], Entry.live.to_a
  end

  private

  def create_entry(title, status, published_at)
    @posts.entries.create!(
      author: @author,
      title: title,
      slug: title.parameterize,
      status: status,
      published_at: published_at,
      data: {}
    )
  end
end
