require "yaml"

module Plum
  # Config-as-code (phase 1): the content model lives as YAML files in the
  # host repo and syncs into the database, like db:migrate for content types.
  #
  #   plum/content_types/posts.yml  ->  Plum::ContentType (blueprint)
  #   plum/fieldsets/seo.yml        ->  Plum::Fieldset
  #
  # Files are the source of truth; `apply` upserts the DB from them, `export`
  # writes the DB back out (bootstrap + CP write-back later), and `check`
  # reports drift for CI. Content (entries, terms, assets) is never touched.
  class ConfigSync
    Result = Struct.new(:created, :updated, :unchanged, :deleted, keyword_init: true) do
      def summary
        "#{created.length} created, #{updated.length} updated, #{unchanged.length} unchanged, #{deleted.length} deleted"
      end
    end

    class DriftError < StandardError; end
    class UnsafePruneError < StandardError; end

    CONTENT_TYPE_DIR = "content_types".freeze
    FIELDSET_DIR = "fieldsets".freeze

    def self.export(site:, dir:)
      new(site: site, dir: dir).export
    end

    def self.apply(site:, dir:, prune: false, force: false)
      new(site: site, dir: dir).apply(prune: prune, force: force)
    end

    def self.check(site:, dir:)
      new(site: site, dir: dir).check
    end

    def initialize(site:, dir:)
      @site = site
      @dir = Pathname(dir)
    end

    # DB -> files. Mirrors the database exactly: stale files for handles that
    # no longer exist are removed.
    def export
      written = []
      written += export_kind(CONTENT_TYPE_DIR, content_types.order(:handle)) { |record| content_type_config(record) }
      written += export_kind(FIELDSET_DIR, fieldsets.order(:handle)) { |record| fieldset_config(record) }
      written
    end

    # Files -> DB. Upserts by handle inside a transaction. Deleting requires
    # prune: true, and deleting a content type that still has entries
    # additionally requires force: true.
    def apply(prune: false, force: false)
      result = Result.new(created: [], updated: [], unchanged: [], deleted: [])

      site.transaction do
        apply_content_types(result)
        apply_fieldsets(result)
        prune_missing(result, force: force) if prune
      end

      result
    end

    # Returns human-readable drift lines; empty means files and DB agree.
    def check
      drift = []
      drift += check_kind(CONTENT_TYPE_DIR, content_types)
      drift += check_kind(FIELDSET_DIR, fieldsets)
      drift
    end

    private

    attr_reader :site, :dir

    # Fresh relations every time — going through site.content_types would
    # cache the association on the site instance and hide later DB changes
    # from repeated check/apply calls.
    def content_types
      ContentType.for_site(site)
    end

    def fieldsets
      Fieldset.for_site(site)
    end

    def export_kind(subdir, records)
      path = dir.join(subdir)
      path.mkpath
      keep = []

      records.each do |record|
        file = path.join("#{record.handle}.yml")
        file.write(yaml_for(yield(record)))
        keep << file
      end

      path.glob("*.yml").each { |file| file.delete unless keep.include?(file) }
      keep
    end

    def apply_content_types(result)
      each_config(CONTENT_TYPE_DIR) do |config, file|
        record = content_types.find_or_initialize_by(handle: config.fetch("handle"))
        record.site = site if record.new_record?
        record.name = config["name"]
        record.icon = config["icon"]
        record.singleton = config["singleton"] unless config["singleton"].nil?
        record.blueprint = merged_blueprint(record, config)
        track(result, record, file)
      end
    end

    def apply_fieldsets(result)
      each_config(FIELDSET_DIR) do |config, file|
        record = fieldsets.find_or_initialize_by(handle: config.fetch("handle"))
        record.site = site if record.new_record?
        record.name = config["name"]
        record.fields = config["fields"] || []
        track(result, record, file)
      end
    end

    # Blueprint keys the files don't know about are preserved so config
    # written by newer Plum versions survives a sync from older files.
    def merged_blueprint(record, config)
      blueprint = (record.blueprint || {}).deep_dup
      blueprint["fields"] = config["fields"] || []
      if config["route_prefix"].present?
        blueprint["route_prefix"] = config["route_prefix"]
      else
        blueprint.delete("route_prefix")
      end
      blueprint
    end

    def track(result, record, file)
      if record.new_record?
        record.save!
        result.created << record.handle
      elsif record.changed?
        record.save!
        result.updated << record.handle
      else
        result.unchanged << record.handle
      end
    rescue ActiveRecord::RecordInvalid => e
      raise ActiveRecord::RecordInvalid.new(e.record), "#{file.basename}: #{e.message}"
    end

    def prune_missing(result, force:)
      file_handles = handles_in(CONTENT_TYPE_DIR)
      content_types.where.not(handle: file_handles).find_each do |record|
        if record.entries.exists? && !force
          raise UnsafePruneError,
                "Content type '#{record.handle}' has #{record.entries.count} entries; " \
                "re-run with FORCE=1 to delete them"
        end
        record.destroy!
        result.deleted << record.handle
      end

      fieldsets.where.not(handle: handles_in(FIELDSET_DIR)).find_each do |record|
        record.destroy!
        result.deleted << record.handle
      end
    end

    def handles_in(subdir)
      handles = []
      each_config(subdir) { |config, _file| handles << config.fetch("handle") }
      handles
    end

    def check_kind(subdir, records)
      drift = []
      configs = {}
      each_config(subdir) { |config, _file| configs[config.fetch("handle")] = config }

      db = records.index_by(&:handle)
      configs.each do |handle, config|
        record = db[handle]
        if record.nil?
          drift << "#{subdir}/#{handle}: in files but not in the database"
        elsif normalize(subdir, config_for(subdir, record)) != normalize(subdir, config)
          drift << "#{subdir}/#{handle}: files and database differ"
        end
      end
      (db.keys - configs.keys).each do |handle|
        drift << "#{subdir}/#{handle}: in the database but not in files"
      end
      drift
    end

    def config_for(subdir, record)
      subdir == CONTENT_TYPE_DIR ? content_type_config(record) : fieldset_config(record)
    end

    # Key order and empty-vs-absent values must not register as drift.
    def normalize(subdir, config)
      if subdir == CONTENT_TYPE_DIR
        {
          "name" => config["name"].to_s,
          "handle" => config["handle"].to_s,
          "icon" => config["icon"].presence,
          "singleton" => !!config["singleton"],
          "route_prefix" => config["route_prefix"].presence,
          "fields" => config["fields"] || []
        }
      else
        {
          "name" => config["name"].to_s,
          "handle" => config["handle"].to_s,
          "fields" => config["fields"] || []
        }
      end
    end

    def content_type_config(record)
      config = {
        "name" => record.name,
        "handle" => record.handle,
        "icon" => record.icon,
        "singleton" => record.singleton,
        "route_prefix" => record.route_prefix,
        "fields" => record.fields
      }
      config.reject { |_key, value| value.nil? }
    end

    def fieldset_config(record)
      { "name" => record.name, "handle" => record.handle, "fields" => record.fields || [] }
    end

    def each_config(subdir)
      dir.join(subdir).glob("*.yml").sort.each do |file|
        config = YAML.safe_load(file.read, aliases: true)
        raise DriftError, "#{file} is not a YAML mapping" unless config.is_a?(Hash)

        config["handle"] ||= file.basename(".yml").to_s
        yield config, file
      end
    end

    def yaml_for(config)
      config.to_yaml
    end
  end
end
