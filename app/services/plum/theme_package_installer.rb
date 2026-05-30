require "fileutils"
require "tmpdir"
require "yaml"
require "zip"

module Plum
  class ThemePackageInstaller
    HANDLE_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/
    SETTING_HANDLE_PATTERN = /\A[a-z][a-z0-9_]*\z/

    PackageEntry = Struct.new(:zip_entry, :path, :directory?, keyword_init: true)

    attr_reader :errors, :theme

    def initialize(package, install_root: nil)
      @package = package
      @install_root = Pathname(install_root || default_install_root)
      @errors = []
      @theme = nil
    end

    def install
      errors.clear

      with_zip_entries do |entries|
        manifest = load_manifest(entries)
        next false if errors.any?

        handle = validate_manifest(manifest)
        validate_renderable_files(entries)
        validate_screenshot(manifest, entries)
        validate_settings(manifest)
        next false if errors.any?

        target_root = validate_target(handle)
        next false if errors.any?

        extract_entries(entries, target_root)
        @theme = Theme.new(root: target_root, manifest: manifest)
        true
      end
    end

    private

    attr_reader :package, :install_root

    def default_install_root
      Plum.configuration.theme_paths.first || Rails.root.join("app/themes")
    end

    def with_zip_entries
      Zip::File.open(package_path) do |zip|
        entries = normalize_entries(zip)
        yield entries
      end
    rescue Zip::Error
      errors << "Theme package must be a valid zip file"
      false
    rescue Errno::ENOENT
      errors << "Theme package could not be found"
      false
    end

    def package_path
      if package.respond_to?(:path)
        package.path
      elsif package.respond_to?(:tempfile) && package.tempfile.respond_to?(:path)
        package.tempfile.path
      else
        package.to_s
      end
    end

    def normalize_entries(zip)
      raw_entries = zip.reject { |entry| ignored_entry?(entry.name) }
      package_root = detect_package_root(raw_entries.reject(&:directory?))

      return [] if errors.any?

      raw_entries.filter_map do |entry|
        relative_path = entry.name.delete_prefix(package_root)
        next if relative_path.blank?

        PackageEntry.new(
          zip_entry: entry,
          path: normalize_entry_path(relative_path),
          directory?: entry.directory?
        )
      rescue ThemeAssetPath::UnsafePathError => e
        errors << e.message
        nil
      end
    end

    def detect_package_root(entries)
      names = entries.map { |entry| normalize_entry_name(entry.name) }.compact

      return "" if names.include?("theme.yml")

      roots = names.filter_map { |name| name.split("/", 2).first if name.include?("/") }.uniq
      root = roots.one? ? "#{roots.first}/" : nil

      if root && names.all? { |name| name.start_with?(root) } && names.include?("#{root}theme.yml")
        root
      else
        errors << "Theme package must contain theme.yml at the root"
        ""
      end
    end

    def normalize_entry_name(name)
      normalize_entry_path(name)
    rescue ThemeAssetPath::UnsafePathError => e
      errors << e.message
      nil
    end

    def normalize_entry_path(path)
      raw_path = path.to_s
      raise ThemeAssetPath::UnsafePathError, "Theme package paths cannot contain backslashes" if raw_path.include?("\\")

      ThemeAssetPath.normalize(raw_path)
    end

    def ignored_entry?(name)
      normalized_name = name.to_s

      normalized_name.start_with?("__MACOSX/") || File.basename(normalized_name) == ".DS_Store"
    end

    def load_manifest(entries)
      manifest_entry = entries.find { |entry| entry.path == "theme.yml" && !entry.directory? }

      unless manifest_entry
        errors << "Theme package must contain theme.yml at the root"
        return {}
      end

      manifest = YAML.safe_load(manifest_entry.zip_entry.get_input_stream.read, aliases: true) || {}
      return manifest.deep_stringify_keys if manifest.is_a?(Hash)

      errors << "theme.yml must contain a mapping"
      {}
    rescue Psych::SyntaxError => e
      errors << "theme.yml is invalid: #{e.message}"
      {}
    end

    def validate_manifest(manifest)
      handle = manifest["handle"].to_s
      name = manifest["name"].to_s

      errors << "theme.yml must define a name" if name.blank?
      if handle.blank?
        errors << "theme.yml must define a handle"
      elsif !handle.match?(HANDLE_PATTERN)
        errors << "theme.yml handle must use lowercase letters, numbers, and hyphens"
      end

      handle
    end

    def validate_screenshot(manifest, entries)
      screenshot = manifest_asset_path(manifest["screenshot"])
      return if screenshot.blank?

      expected_entry_path = "assets/#{screenshot}"
      has_screenshot = entries.any? do |entry|
        !entry.directory? && entry.path == expected_entry_path
      end

      errors << "theme.yml screenshot must point to a file inside assets" unless has_screenshot
    end

    def validate_settings(manifest)
      fields = manifest.dig("settings", "fields")
      return if fields.blank?

      unless fields.is_a?(Array)
        errors << "theme.yml settings.fields must be an array"
        return
      end

      fields.each_with_index do |field, index|
        validate_setting_field(field, index + 1)
      end
    end

    def validate_setting_field(field, position)
      unless field.is_a?(Hash)
        errors << "theme.yml settings field #{position} must be a mapping"
        return
      end

      field = field.deep_stringify_keys
      handle = field["handle"].to_s
      type = field["type"].presence || "text"

      if handle.blank?
        errors << "theme.yml settings field #{position} must define a handle"
      elsif !handle.match?(SETTING_HANDLE_PATTERN)
        errors << "theme.yml settings field #{handle} must use lowercase letters, numbers, and underscores"
      end

      unless Theme::SUPPORTED_SETTING_TYPES.include?(type)
        errors << "theme.yml settings field #{handle.presence || position} has unsupported type #{type}"
        return
      end

      validate_select_setting(field, handle.presence || position) if type == "select"
    end

    def validate_select_setting(field, identifier)
      values = select_option_values(field["options"])

      if values.blank?
        errors << "theme.yml settings field #{identifier} must define select options"
        return
      end

      default_value = field["default"].to_s
      if field.key?("default") && values.exclude?(default_value)
        errors << "theme.yml settings field #{identifier} default must match one of its options"
      end
    end

    def select_option_values(options)
      return [] unless options.is_a?(Array)

      options.filter_map do |option|
        if option.is_a?(Hash)
          option.deep_stringify_keys["value"].to_s.presence
        else
          option.to_s.presence
        end
      end
    end

    def manifest_asset_path(path)
      raw_path = path.to_s
      return if raw_path.blank?

      raw_path = raw_path.delete_prefix("assets/")
      normalize_entry_path(raw_path)
    rescue ThemeAssetPath::UnsafePathError
      errors << "theme.yml screenshot path must be a safe asset path"
      nil
    end

    def validate_renderable_files(entries)
      has_renderable_file = entries.any? do |entry|
        !entry.directory? && entry.path.match?(%r{\A(layouts|templates)/.+\.liquid\z})
      end

      errors << "Theme package must include at least one Liquid layout or template" unless has_renderable_file
    end

    def validate_target(handle)
      target_root = install_root.expand_path.join(handle)

      errors << "Theme #{handle} is already installed" if target_root.exist?

      target_root
    end

    def extract_entries(entries, target_root)
      FileUtils.mkdir_p(install_root)

      Dir.mktmpdir("plum-theme-package-") do |dir|
        staging_root = Pathname(dir).join(target_root.basename.to_s)

        entries.each do |entry|
          destination = staging_root.join(entry.path)
          if entry.directory?
            FileUtils.mkdir_p(destination)
          else
            FileUtils.mkdir_p(destination.dirname)
            destination.binwrite(entry.zip_entry.get_input_stream.read)
          end
        end

        FileUtils.mv(staging_root, target_root)
      end
    end
  end
end
