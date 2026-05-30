require "fileutils"
require "tmpdir"
require "yaml"
require "zip"

module Plum
  class ThemePackageInstaller
    HANDLE_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/

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
