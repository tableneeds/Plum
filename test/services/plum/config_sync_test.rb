require "test_helper"

module Plum
  class ConfigSyncTest < ActiveSupport::TestCase
    setup do
      @site = Plum::Site.first_or_create_standalone!(skip_defaults: true)
      @dir = Rails.root.join("tmp", "config-sync-#{SecureRandom.hex(6)}")
    end

    teardown do
      FileUtils.rm_rf(@dir)
    end

    test "export writes one YAML file per content type and fieldset, mirroring the database" do
      @site.content_types.create!(name: "Posts", handle: "posts",
        blueprint: { "route_prefix" => "blog", "fields" => [ { "handle" => "body", "type" => "rich_text" } ] })
      @site.fieldsets.create!(name: "SEO", handle: "seo", fields: [ { "handle" => "meta_title", "type" => "text" } ])
      stale = @dir.join("content_types/old_type.yml")
      stale.dirname.mkpath
      stale.write("name: Old\n")

      ConfigSync.export(site: @site, dir: @dir)

      config = YAML.safe_load(@dir.join("content_types/posts.yml").read)
      assert_equal "Posts", config["name"]
      assert_equal "blog", config["route_prefix"]
      assert_equal "body", config.dig("fields", 0, "handle")
      assert @dir.join("fieldsets/seo.yml").exist?
      assert_not stale.exist?, "export should remove files for deleted records"
    end

    test "apply creates content types and fieldsets from files" do
      write_config("content_types/posts.yml", {
        "name" => "Posts", "route_prefix" => "blog",
        "fields" => [ { "handle" => "body", "type" => "rich_text", "label" => "Body" } ]
      })
      write_config("fieldsets/seo.yml", { "name" => "SEO", "fields" => [ { "handle" => "meta_title", "type" => "text" } ] })

      result = ConfigSync.apply(site: @site, dir: @dir)

      assert_equal %w[posts seo], result.created.sort
      posts = @site.content_types.find_by!(handle: "posts")
      assert_equal "Posts", posts.name
      assert_equal "blog", posts.route_prefix
      assert_equal "rich_text", posts.fields.first["type"]
      assert @site.fieldsets.exists?(handle: "seo")
    end

    test "apply updates existing types, keeps entries, and is idempotent" do
      posts = @site.content_types.create!(name: "Posts", handle: "posts",
        blueprint: { "fields" => [ { "handle" => "body", "type" => "rich_text" } ] })
      entry = posts.entries.create!(site: @site, title: "Keep me", slug: "keep-me", status: :draft,
        data: { "body" => "<p>hi</p>" })
      write_config("content_types/posts.yml", {
        "name" => "Blog Posts",
        "fields" => [
          { "handle" => "body", "type" => "rich_text" },
          { "handle" => "excerpt", "type" => "textarea" }
        ]
      })

      result = ConfigSync.apply(site: @site, dir: @dir)
      assert_equal [ "posts" ], result.updated

      posts.reload
      assert_equal "Blog Posts", posts.name
      assert_equal %w[body excerpt], posts.fields.map { |field| field["handle"] }
      assert Plum::Entry.exists?(entry.id), "apply must never touch entries"

      second = ConfigSync.apply(site: @site, dir: @dir)
      assert_equal [ "posts" ], second.unchanged
      assert_empty second.updated
    end

    test "apply preserves blueprint keys the files do not manage" do
      @site.content_types.create!(name: "Posts", handle: "posts",
        blueprint: { "fields" => [], "custom_extension_key" => "kept" })
      write_config("content_types/posts.yml", { "name" => "Posts", "fields" => [] })

      ConfigSync.apply(site: @site, dir: @dir)

      assert_equal "kept", @site.content_types.find_by!(handle: "posts").blueprint["custom_extension_key"]
    end

    test "apply without prune leaves types missing from files alone" do
      @site.content_types.create!(name: "Legacy", handle: "legacy", blueprint: { "fields" => [] })
      write_config("content_types/posts.yml", { "name" => "Posts", "fields" => [] })

      ConfigSync.apply(site: @site, dir: @dir)

      assert @site.content_types.exists?(handle: "legacy")
    end

    test "prune deletes types absent from files but refuses when entries exist without force" do
      empty = @site.content_types.create!(name: "Empty", handle: "empty_type", blueprint: { "fields" => [] })
      full = @site.content_types.create!(name: "Full", handle: "full_type", blueprint: { "fields" => [] })
      full.entries.create!(site: @site, title: "Data", slug: "config-data", status: :draft)
      write_config("content_types/posts.yml", { "name" => "Posts", "fields" => [] })

      assert_raises(ConfigSync::UnsafePruneError) do
        ConfigSync.apply(site: @site, dir: @dir, prune: true)
      end
      assert @site.content_types.exists?(handle: "empty_type"), "failed prune must roll back everything"

      result = ConfigSync.apply(site: @site, dir: @dir, prune: true, force: true)
      assert_includes result.deleted, "empty_type"
      assert_includes result.deleted, "full_type"
      assert_not Plum::ContentType.exists?(empty.id)
    end

    test "apply reports the offending file for invalid blueprints" do
      write_config("content_types/bad.yml", { "name" => "Bad", "fields" => [ { "handle" => "x", "type" => "not_a_type" } ] })

      error = assert_raises(ActiveRecord::RecordInvalid) { ConfigSync.apply(site: @site, dir: @dir) }
      assert_includes error.message, "bad.yml"
    end

    test "check is clean after export and reports drift after DB edits" do
      @site.content_types.create!(name: "Posts", handle: "posts",
        blueprint: { "fields" => [ { "handle" => "body", "type" => "rich_text" } ] })
      ConfigSync.export(site: @site, dir: @dir)

      assert_empty ConfigSync.check(site: @site, dir: @dir)

      @site.content_types.find_by!(handle: "posts").update!(name: "Renamed in prod")
      drift = ConfigSync.check(site: @site, dir: @dir)
      assert_equal 1, drift.length
      assert_includes drift.first, "content_types/posts"

      @site.content_types.create!(name: "Sneaky", handle: "sneaky", blueprint: { "fields" => [] })
      assert(ConfigSync.check(site: @site, dir: @dir).any? { |line| line.include?("sneaky") })
    end

    test "handle falls back to the filename" do
      write_config("content_types/from_filename.yml", { "name" => "From Filename", "fields" => [] })

      ConfigSync.apply(site: @site, dir: @dir)

      assert @site.content_types.exists?(handle: "from_filename")
    end

    private

    def write_config(relative_path, config)
      file = @dir.join(relative_path)
      file.dirname.mkpath
      file.write(config.to_yaml)
    end
  end
end
