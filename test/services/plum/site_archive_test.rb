require "test_helper"

module Plum
  class SiteArchiveTest < ActiveSupport::TestCase
    test "exports and imports a complete portable site with remapped references" do
      source = Site.create!(name: "Portable Plum", domain: "old.example", theme_name: "default", skip_defaults: true)
      content_type = source.content_types.create!(
        name: "Articles",
        handle: "articles",
        blueprint: { "fields" => [
          { "handle" => "hero", "type" => "image" },
          { "handle" => "related", "type" => "relationship", "multiple" => true }
        ] }
      )
      asset = source.assets.new(alt_text: "Plum", folder: "editorial", focal_x: 30, focal_y: 40)
      attach_test_png(asset, filename: "plum.png")
      asset.save!
      taxonomy = source.taxonomies.create!(name: "Topics", handle: "topics", slug: "topics")
      term = taxonomy.terms.create!(site: source, name: "Rails", slug: "rails")
      related = source.entries.create!(content_type: content_type, title: "Related", slug: "related", status: :published, data: {})
      article = source.entries.create!(
        content_type: content_type,
        title: "Portable",
        slug: "portable",
        status: :draft,
        data: { "hero" => asset.id.to_s, "related" => [ related.id.to_s ] },
        terms: [ term ]
      )
      article.record_revision!
      menu = source.nav_menus.create!(name: "Main", handle: "main")
      menu.nav_items.create!(site: source, label: "Portable", entry: article, position: 1)
      source.globals.create!(name: "Company", handle: "company", data: { "phone" => "555-0100" })
      form = source.form_definitions.create!(name: "Contact", handle: "contact", fields: [ { "handle" => "email", "type" => "email" } ])
      form.form_submissions.create!(site: source, data: { "email" => "hello@example.com" })
      source.fieldsets.create!(name: "SEO", handle: "seo", fields: [ { "handle" => "description", "type" => "text" } ])
      SiteSetting.create!(site: source, name: source.name, theme_name: "default", logo: asset.id.to_s)

      archive = Rails.root.join("tmp", "#{SecureRandom.hex}.plum.zip")
      SiteArchive.dump(site: source, path: archive)
      restored = SiteArchive.load(path: archive, name: "Restored Plum", domain: "new.example")

      assert_equal "Restored Plum", restored.name
      assert_equal "new.example", restored.domain
      assert_equal 1, restored.assets.count
      assert_equal "plum.png", restored.assets.first.filename
      assert_equal "Plum", restored.assets.first.alt_text
      imported_article = restored.entries.find_by!(slug: "portable")
      imported_related = restored.entries.find_by!(slug: "related")
      assert_equal restored.assets.first.id.to_s, imported_article.data["hero"].to_s
      assert_equal [ imported_related.id.to_s ], imported_article.data["related"].map(&:to_s)
      assert_equal [ "Rails" ], imported_article.terms.pluck(:name)
      assert_equal 1, imported_article.revisions.count
      assert_equal imported_article.id, restored.nav_items.first.entry_id
      assert_equal 1, restored.form_submissions.count
      assert_equal 1, restored.fieldsets.count
      assert_equal restored.assets.first.id.to_s, restored.site_setting.logo
    ensure
      FileUtils.rm_f(archive) if archive
    end

    test "rejects archives with a corrupted asset" do
      site = Site.create!(name: "Checksum", theme_name: "default", skip_defaults: true)
      asset = site.assets.new
      attach_test_png(asset)
      asset.save!
      archive = Rails.root.join("tmp", "#{SecureRandom.hex}.plum.zip")
      SiteArchive.dump(site: site, path: archive)

      Zip::File.open(archive) do |zip|
        manifest = JSON.parse(zip.read("manifest.json"))
        manifest["assets"].first["checksum"] = "definitely-wrong"
        zip.get_output_stream("manifest.json") { |stream| stream.write(JSON.generate(manifest)) }
      end

      error = assert_raises(SiteArchive::InvalidArchive) { SiteArchive.load(path: archive) }
      assert_match(/failed its checksum/, error.message)
      assert_equal 1, Site.where(name: "Checksum").count
    ensure
      FileUtils.rm_f(archive) if archive
    end
  end
end
