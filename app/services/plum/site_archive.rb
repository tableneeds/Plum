require "json"
require "zip"
require "digest"
require "tempfile"

module Plum
  module SiteArchive
    FORMAT = "plum-site"
    VERSION = 1

    class Error < StandardError; end
    class InvalidArchive < Error; end

    module_function

    def dump(site:, path:)
      Exporter.new(site).write(path)
    end

    def load(path:, name: nil, domain: nil)
      Importer.new(path).import(name: name, domain: domain)
    end

    class Exporter
      def initialize(site)
        @site = site
      end

      def write(path)
        destination = Pathname(path).expand_path
        destination.dirname.mkpath
        FileUtils.rm_f(destination)

        Zip::File.open(destination, create: true) do |zip|
          zip.get_output_stream("manifest.json") { |stream| stream.write(JSON.pretty_generate(manifest)) }
          site.assets.with_attached_file.find_each do |asset|
            next unless asset.file.attached?

            zip.get_output_stream(asset_path(asset)) do |stream|
              asset.file.blob.open { |file| IO.copy_stream(file, stream) }
            end
          end
        end
        destination
      end

      private

      attr_reader :site

      def manifest
        {
          "format" => FORMAT,
          "format_version" => VERSION,
          "plum_version" => Plum::VERSION,
          "exported_at" => Time.current.iso8601,
          "site" => record(site, %w[id name domain theme_name settings theme_settings custom_css]),
          "site_setting" => site.site_setting && record(site.site_setting, site_setting_fields),
          "content_types" => records(site.content_types, %w[id name handle singleton blueprint icon]),
          "fieldsets" => records(site.fieldsets, %w[id name handle fields]),
          "taxonomies" => records(site.taxonomies, %w[id name handle slug]),
          "terms" => records(site.terms, %w[id taxonomy_id name slug position]),
          "assets" => site.assets.with_attached_file.order(:id).map { |asset| asset_record(asset) },
          "entries" => site.entries.order(:id).map { |entry| entry_record(entry) },
          "entry_revisions" => revision_records,
          "globals" => records(site.globals, %w[id name handle data]),
          "nav_menus" => records(site.nav_menus, %w[id name handle]),
          "nav_items" => records(site.nav_items.unscoped.where(site: site), %w[id nav_menu_id parent_id entry_id label url position]),
          "form_definitions" => records(site.form_definitions, %w[id name handle fields notification_email]),
          "form_submissions" => records(site.form_submissions, %w[id form_definition_id data created_at updated_at])
        }.compact
      end

      def site_setting_fields
        %w[name tagline logo favicon seo_title seo_description theme_name primary_color support_email]
      end

      def entry_record(entry)
        record(entry, %w[id content_type_id title slug status data published_at author_name author_email author_gid locale origin_id]).merge(
          "term_ids" => entry.term_ids
        )
      end

      def revision_records
        site.entries.includes(:revisions).flat_map do |entry|
          entry.revisions.order(:id).map do |revision|
            record(revision, %w[id entry_id editor_name editor_email editor_gid snapshot created_at updated_at])
          end
        end
      end

      def asset_record(asset)
        record(asset, %w[id alt_text caption folder focal_x focal_y]).merge(
          "filename" => asset.filename,
          "content_type" => asset.content_type,
          "byte_size" => asset.file.byte_size,
          "checksum" => asset.file.blob.checksum,
          "path" => asset_path(asset)
        )
      end

      def asset_path(asset)
        "assets/#{asset.id}/#{asset.filename.gsub(/[^A-Za-z0-9._-]/, "_")}"
      end

      def records(scope, fields)
        scope.order(:id).map { |item| record(item, fields) }
      end

      def record(item, fields)
        item.attributes.slice(*fields)
      end
    end

    class Importer
      def initialize(path)
        @path = Pathname(path).expand_path
        @maps = Hash.new { |hash, key| hash[key] = {} }
        @uploaded_blobs = []
      end

      def import(name: nil, domain: nil)
        raise InvalidArchive, "Archive does not exist: #{path}" unless path.file?

        Zip::File.open(path) do |zip|
          @zip = zip
          @data = parse_manifest(zip)
          validate_manifest!
          ActiveRecord::Base.transaction { import_site(name:, domain:) }
        end
      rescue StandardError => error
        cleanup_uploaded_files
        raise unless error.is_a?(Zip::Error) || error.is_a?(JSON::ParserError)

        raise InvalidArchive, error.message
      ensure
        @zip = nil
      end

      private

      attr_reader :path, :data, :maps, :zip

      def parse_manifest(zip_file)
        entry = zip_file.find_entry("manifest.json")
        raise InvalidArchive, "Archive is missing manifest.json" unless entry

        JSON.parse(entry.get_input_stream.read)
      end

      def validate_manifest!
        raise InvalidArchive, "Not a Plum site archive" unless data["format"] == FORMAT
        raise InvalidArchive, "Unsupported archive version #{data['format_version'].inspect}" unless data["format_version"] == VERSION
        raise InvalidArchive, "Archive is missing site data" unless data["site"].is_a?(Hash)
      end

      def import_site(name:, domain:)
        source = data.fetch("site")
        @site = Site.create!(
          name: name.presence || source.fetch("name"),
          domain: domain.nil? ? source["domain"] : domain,
          theme_name: source["theme_name"],
          settings: source["settings"] || {},
          theme_settings: source["theme_settings"] || {},
          custom_css: source["custom_css"],
          skip_defaults: true
        )
        maps[:sites][source["id"]] = @site.id

        import_simple(:content_types, ContentType, %w[name handle singleton blueprint icon])
        import_simple(:fieldsets, Fieldset, %w[name handle fields])
        import_simple(:taxonomies, Taxonomy, %w[name handle slug])
        import_terms
        import_assets
        import_entries
        import_entry_links
        import_globals
        import_navigation
        import_forms
        import_site_setting
        @site
      end

      def import_simple(key, model, fields)
        Array(data[key.to_s]).each do |source|
          item = model.create!(source.slice(*fields).merge("site_id" => @site.id))
          maps[key][source["id"]] = item.id
        end
      end

      def import_terms
        Array(data["terms"]).each do |source|
          term = Term.create!(source.slice("name", "slug", "position").merge(
            "site_id" => @site.id,
            "taxonomy_id" => mapped!(:taxonomies, source["taxonomy_id"])
          ))
          maps[:terms][source["id"]] = term.id
        end
      end

      def import_assets
        Array(data["assets"]).each do |source|
          archive_entry = zip.find_entry(source.fetch("path"))
          raise InvalidArchive, "Archive is missing asset #{source['path']}" unless archive_entry

          asset = import_asset(source, archive_entry)
          maps[:assets][source["id"]] = asset.id
        end
      end

      def import_asset(source, archive_entry)
        Tempfile.create([ "plum-asset", File.extname(source.fetch("filename")) ], binmode: true) do |file|
          digest = Digest::MD5.new
          bytes = 0
          input = archive_entry.get_input_stream
          while (chunk = input.read(64 * 1024))
            file.write(chunk)
            digest.update(chunk)
            bytes += chunk.bytesize
          end
          expected_checksum = source["checksum"].to_s
          actual_checksum = [ digest.digest ].pack("m0")
          raise InvalidArchive, "Asset #{source['path']} has an invalid size" if source["byte_size"].present? && bytes != source["byte_size"].to_i
          raise InvalidArchive, "Asset #{source['path']} failed its checksum" if expected_checksum.present? && actual_checksum != expected_checksum

          file.rewind
          asset = Asset.new(source.slice("alt_text", "caption", "folder", "focal_x", "focal_y").merge("site_id" => @site.id))
          blob = ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: source.fetch("filename"),
            content_type: source["content_type"]
          )
          @uploaded_blobs << blob
          asset.file.attach(blob)
          asset.save!
          asset
        end
      end

      def import_entries
        Array(data["entries"]).each do |source|
          entry = Entry.create!(source.slice("title", "slug", "status", "data", "published_at", "author_name", "author_email", "author_gid", "locale").merge(
            "site_id" => @site.id,
            "content_type_id" => mapped!(:content_types, source["content_type_id"])
          ))
          maps[:entries][source["id"]] = entry.id
        end
      end

      def import_entry_links
        entries_by_id = Array(data["entries"]).index_by { |item| item["id"] }
        entries_by_id.each do |old_id, source|
          entry = Entry.find(mapped!(:entries, old_id))
          fields = entry.content_type.fields
          entry.update_columns(
            data: remap_field_values(source["data"] || {}, fields),
            origin_id: mapped(:entries, source["origin_id"]),
            updated_at: Time.current
          )
          entry.term_ids = Array(source["term_ids"]).filter_map { |id| mapped(:terms, id) }
        end

        Array(data["entry_revisions"]).each do |source|
          snapshot = source["snapshot"].to_h.deep_dup
          entry = Entry.find(mapped!(:entries, source["entry_id"]))
          snapshot["data"] = remap_field_values(snapshot["data"] || {}, entry.content_type.fields)
          snapshot["term_ids"] = Array(snapshot["term_ids"]).filter_map { |id| mapped(:terms, id) }
          EntryRevision.create!(source.slice("editor_name", "editor_email", "editor_gid", "created_at", "updated_at").merge(
            "site_id" => @site.id, "entry_id" => entry.id, "snapshot" => snapshot
          ))
        end
      end

      def remap_field_values(values, fields)
        result = values.to_h.deep_dup
        Array(fields).each do |field|
          handle = field["handle"].to_s
          value = result[handle]
          result[handle] = case field["type"]
          when "image" then mapped(:assets, value)
          when "images" then Array(value).filter_map { |id| mapped(:assets, id) }
          when "relationship"
            field["multiple"] ? Array(value).filter_map { |id| mapped(:entries, id) } : mapped(:entries, value)
          when "group" then remap_field_values(value || {}, field["fields"])
          when "repeater" then Array(value).map { |row| remap_field_values(row, field["fields"]) }
          when "blocks" then remap_blocks(value)
          else value
          end
        end
        result
      end

      def remap_blocks(value)
        library = BlockLibrary.new(@site.theme)
        Array(value).map do |block|
          restored = block.to_h.deep_dup
          definition = library.definition(restored["type"])
          restored["fields"] = remap_field_values(restored["fields"] || {}, definition&.dig("fields") || [])
          restored
        end
      end

      def import_globals
        Array(data["globals"]).each do |source|
          Global.create!(source.slice("name", "handle", "data").merge("site_id" => @site.id))
        end
      end

      def import_navigation
        import_simple(:nav_menus, NavMenu, %w[name handle])
        pending = Array(data["nav_items"]).sort_by { |item| item["parent_id"].present? ? 1 : 0 }
        until pending.empty?
          imported = pending.reject! do |source|
            next false if source["parent_id"].present? && mapped(:nav_items, source["parent_id"]).blank?

            item = NavItem.create!(source.slice("label", "url", "position").merge(
              "site_id" => @site.id,
              "nav_menu_id" => mapped!(:nav_menus, source["nav_menu_id"]),
              "parent_id" => mapped(:nav_items, source["parent_id"]),
              "entry_id" => mapped(:entries, source["entry_id"])
            ))
            maps[:nav_items][source["id"]] = item.id
            true
          end
          raise InvalidArchive, "Navigation contains an invalid parent cycle" unless imported
        end
      end

      def import_forms
        import_simple(:form_definitions, FormDefinition, %w[name handle fields notification_email])
        Array(data["form_submissions"]).each do |source|
          submission = FormSubmission.new(source.slice("data", "created_at", "updated_at").merge(
            "site_id" => @site.id,
            "form_definition_id" => mapped!(:form_definitions, source["form_definition_id"])
          ))
          submission.save!(validate: false)
        end
      end

      def import_site_setting
        source = data["site_setting"]
        return SiteSetting.instance(@site) unless source

        attributes = source.except("id")
        attributes["logo"] = mapped(:assets, source["logo"].to_i)&.to_s if source["logo"].present?
        attributes["favicon"] = mapped(:assets, source["favicon"].to_i)&.to_s if source["favicon"].present?
        SiteSetting.create!(attributes.merge("site_id" => @site.id))
      end

      def mapped(type, old_id)
        return if old_id.blank?

        maps[type][old_id] || maps[type][old_id.to_i]
      end

      def mapped!(type, old_id)
        mapped(type, old_id) || raise(InvalidArchive, "Missing #{type.to_s.singularize} reference #{old_id.inspect}")
      end

      def cleanup_uploaded_files
        @uploaded_blobs.each { |blob| blob.service.delete(blob.key) }
      rescue StandardError
        nil
      end
    end
  end
end
