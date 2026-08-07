require "test_helper"

class EntryTest < ActiveSupport::TestCase
  setup do
    @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
    @author = Plum::User.create!(
      email: "author@example.com",
      password: "password123",
      role: :admin
    )
    @posts = @site.content_types.create!(
      name: "Blog Posts",
      handle: "posts",
      blueprint: { "fields" => [] }
    )
  end

  test "status enum matches the brief" do
    assert_equal({ "draft" => 0, "published" => 1, "scheduled" => 2 }, Plum::Entry.statuses)
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

    assert_equal [ live ], Plum::Entry.live.to_a
  end

  test "validates required blueprint fields" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "dek", "type" => "text", "label" => "Summary", "required" => true }
    ] })

    entry = @posts.entries.new(site: @site, author: @author, title: "Incomplete", status: :draft, data: {})

    assert_not entry.valid?
    assert_includes entry.errors[:data], "Summary is required"
    entry.data["dek"] = "A useful summary"
    assert entry.valid?
  end

  test "false satisfies a required boolean field" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "featured", "type" => "boolean", "required" => true }
    ] })

    entry = @posts.entries.new(site: @site, author: @author, title: "Not Featured", status: :draft, data: { "featured" => false })

    assert entry.valid?
  end

  test "validates required fields inside groups and repeater rows" do
    nested_fields = [ { "handle" => "name", "type" => "text", "label" => "Name", "required" => true } ]
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "contact", "type" => "group", "label" => "Contact", "fields" => nested_fields },
      { "handle" => "people", "type" => "repeater", "label" => "People", "fields" => nested_fields }
    ] })
    entry = @posts.entries.new(
      site: @site,
      author: @author,
      title: "Directory",
      status: :draft,
      data: { "contact" => { "name" => "" }, "people" => [ { "name" => "" } ] }
    )

    assert_not entry.valid?
    assert_includes entry.errors[:data], "Contact Name is required"
    assert_includes entry.errors[:data], "People row 1 Name is required"
  end

  test "validates collection constraints" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "tags", "type" => "list", "min_items" => 2, "max_items" => 3, "unique" => true }
    ] })
    entry = @posts.entries.new(site: @site, author: @author, title: "Tags", status: :draft, data: { "tags" => [ "Ruby", "ruby" ] })

    assert_not entry.valid?
    assert_includes entry.errors[:data], "Tags values must be unique"
    entry.data["tags"] = [ "Ruby" ]
    assert_not entry.valid?
    assert_includes entry.errors[:data], "Tags must have at least 2 items"
  end

  test "validates number mode bounds and step" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "rating", "type" => "number", "number_kind" => "integer", "min" => "1", "max" => "5", "step" => "2" }
    ] })
    entry = @posts.entries.new(site: @site, author: @author, title: "Rating", status: :draft, data: { "rating" => "2.5" })

    assert_not entry.valid?
    assert_includes entry.errors[:data], "Rating must be a whole number"
    entry.data["rating"] = "4"
    assert_not entry.valid?
    assert_includes entry.errors[:data], "Rating does not match the required step"
    entry.data["rating"] = "5"
    assert entry.valid?
  end

  test "validates configured date bounds" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "event_date", "type" => "date", "min" => "2026-01-01", "max" => "2026-12-31" }
    ] })
    entry = @posts.entries.new(site: @site, author: @author, title: "Event", status: :draft, data: { "event_date" => "2027-01-01" })

    assert_not entry.valid?
    assert_includes entry.errors[:data], "Event Date must be on or before 2026-12-31"
  end

  test "required conditional fields validate only while visible" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "featured", "type" => "boolean" },
      { "handle" => "dek", "type" => "text", "required" => true, "condition" => { "field" => "featured", "operator" => "equals", "value" => "true" } }
    ] })
    entry = @posts.entries.new(site: @site, author: @author, title: "Conditional", status: :draft, data: { "featured" => false })

    assert entry.valid?
    entry.data["featured"] = true
    assert_not entry.valid?
    assert_includes entry.errors[:data], "Dek is required"
  end

  test "validates configured option values" do
    @posts.update!(blueprint: { "fields" => [
      { "handle" => "layout", "type" => "button_group", "options" => [ { "label" => "Feature", "value" => "feature" } ] }
    ] })
    entry = @posts.entries.new(site: @site, author: @author, title: "Options", status: :draft, data: { "layout" => "unknown" })

    assert_not entry.valid?
    assert_includes entry.errors[:data], "Layout contains an invalid option"
    entry.data["layout"] = "feature"
    assert entry.valid?
  end

  test "allows matching slugs in different locales" do
    english = @posts.entries.create!(site: @site, author: @author, title: "About", slug: "about", locale: "en", status: :draft, data: {})
    spanish = @posts.entries.new(site: @site, author: @author, origin: english, title: "Acerca", slug: "about", locale: "es", status: :draft, data: {})

    assert spanish.valid?, spanish.errors.full_messages.to_sentence
  end

  private

  def create_entry(title, status, published_at)
    @posts.entries.create!(
      site: @site,
      author: @author,
      title: title,
      slug: title.parameterize,
      status: status,
      published_at: published_at,
      data: {}
    )
  end
end
