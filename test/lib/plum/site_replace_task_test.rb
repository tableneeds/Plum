require "test_helper"
require "rake"

module Plum
  class SiteReplaceTaskTest < ActiveSupport::TestCase
    setup do
      Rails.application.load_tasks unless Rake::Task.task_defined?("plum:site:replace")
      @archive_path = Rails.root.join("tmp", "replace-test-#{SecureRandom.hex(6)}.plum.zip")
    end

    teardown do
      FileUtils.rm_f(@archive_path)
      Rake::Task["plum:site:replace"].reenable
      ENV.delete("ARCHIVE")
      ENV.delete("SITE_ID")
    end

    test "replace swaps the current site for the archived one without stacking sites" do
      site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      posts = site.content_types.create!(name: "Posts", handle: "replace_posts",
        blueprint: { "fields" => [ { "handle" => "body", "type" => "rich_text" } ] })
      posts.entries.create!(site: site, title: "Production truth", slug: "production-truth",
        status: :published, published_at: 1.hour.ago, data: { "body" => "<p>Prod</p>" })
      # Every real site has a homepage; its destroy guard must not abort the
      # replace (regression caught by the first live `plum pull`).
      posts.entries.create!(site: site, title: "Home", slug: Plum::Entry::HOMEPAGE_SLUG,
        status: :published, published_at: 1.hour.ago)
      Plum::SiteArchive.dump(site: site, path: @archive_path)

      # Local drift that the pull should wipe out.
      posts.entries.create!(site: site, title: "Local junk", slug: "local-junk", status: :draft)
      before_count = Plum::Site.count

      ENV["ARCHIVE"] = @archive_path.to_s
      ENV["SITE_ID"] = site.id.to_s
      # execute, not invoke: the :environment prerequisite would reconnect
      # Active Record outside the test transaction.
      Rake::Task["plum:site:replace"].execute

      assert_equal before_count, Plum::Site.count, "replace must not accumulate sites"
      assert_not Plum::Site.exists?(site.id)
      restored = Plum::Site.order(:id).last
      assert restored.entries.exists?(slug: "production-truth")
      assert_not restored.entries.exists?(slug: "local-junk")
    end
  end
end
