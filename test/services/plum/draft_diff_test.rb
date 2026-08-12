require "test_helper"

module Plum
  class DraftDiffTest < ActiveSupport::TestCase
    setup do
      @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      @posts = @site.content_types.create!(
        name: "Posts", handle: "diff_posts",
        blueprint: { "fields" => [
          { "handle" => "body", "type" => "rich_text", "label" => "Body" },
          { "handle" => "tags", "type" => "list", "label" => "Tags" }
        ] }
      )
      @entry = @posts.entries.create!(
        site: @site, title: "Original title", slug: "diff-post", status: :published, published_at: 1.hour.ago,
        data: { "body" => "<p>The quick brown fox jumps.</p>", "tags" => [ "a", "b" ] }
      )
    end

    test "word_diff marks insertions, deletions, and equal runs" do
      segments = DraftDiff.word_diff("the quick brown fox", "the slow brown fox jumps")

      assert_includes segments, [ :del, "quick" ]
      assert_includes segments, [ :ins, "slow" ]
      assert_includes segments, [ :ins, " jumps" ]
      reconstructed_old = segments.reject { |op, _| op == :ins }.map(&:last).join
      reconstructed_new = segments.reject { |op, _| op == :del }.map(&:last).join
      assert_equal "the quick brown fox", reconstructed_old
      assert_equal "the slow brown fox jumps", reconstructed_new
    end

    test "reports no changes without meaningful differences" do
      @entry.save_draft!(title: @entry.title, data: @entry.data.to_h)

      assert_not DraftDiff.new(@entry).any?
    end

    test "diffs title, rich text as readable text, and structured fields" do
      @entry.save_draft!(
        title: "Better title",
        data: { "body" => "<p>The slow brown fox jumps.</p>", "tags" => [ "a", "c" ] }
      )

      diff = DraftDiff.new(@entry)
      labels = diff.changes.map(&:label)
      assert_equal [ "Title", "Body", "Tags" ], labels

      body_change = diff.changes.find { |change| change.handle == "body" }
      assert_includes body_change.segments, [ :del, "quick" ]
      assert_includes body_change.segments, [ :ins, "slow" ]
      refute body_change.segments.flatten.join.include?("<p>"), "rich text should be diffed as text, not markup"

      tags_change = diff.changes.find { |change| change.handle == "tags" }
      assert tags_change.segments.any? { |op, text| op == :del && text.include?("b") }
      assert tags_change.segments.any? { |op, text| op == :ins && text.include?("c") }
    end

    test "fields untouched by the draft are not reported" do
      @entry.save_draft!(title: @entry.title, data: { "body" => "<p>New body.</p>" })

      diff = DraftDiff.new(@entry)
      assert_equal [ "body" ], diff.changes.map(&:handle)
    end

    test "oversized changes fall back to wholesale replacement" do
      old_text = (1..3000).map { |i| "old#{i}" }.join(" ")
      new_text = (1..3000).map { |i| "new#{i}" }.join(" ")

      segments = DraftDiff.word_diff(old_text, new_text)

      assert_equal [ :del, :ins ], segments.map(&:first)
    end
  end
end
