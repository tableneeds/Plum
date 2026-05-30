require "yaml"

module Plum
  class ThemeManifestError < StandardError; end

  class ThemeRegistry
    DEFAULT_THEME_HANDLE = "default"

    attr_reader :theme_paths

    def initialize(theme_paths: Plum.configuration.theme_paths)
      @theme_paths = Array(theme_paths).compact.map { |path| Pathname(path).expand_path }.uniq(&:to_s)
    end

    def all
      themes_by_handle.values
    end

    def find(handle)
      themes_by_handle[handle.to_s] if handle.present?
    end

    def fetch(handle)
      find(handle) || default_theme
    end

    def default_theme
      find(DEFAULT_THEME_HANDLE)
    end

    private

    def themes_by_handle
      @themes_by_handle ||= discover_themes
    end

    def discover_themes
      theme_paths.each_with_object({}) do |theme_path, themes|
        next unless theme_path.directory?

        theme_path.children.select(&:directory?).sort.each do |theme_root|
          theme = build_theme(theme_root)
          themes[theme.handle] ||= theme
        end
      end
    end

    def build_theme(theme_root)
      Theme.new(root: theme_root, manifest: load_manifest(theme_root.join("theme.yml")))
    end

    def load_manifest(path)
      return {} unless path.file?

      manifest = YAML.safe_load(path.read, aliases: true) || {}
      return manifest if manifest.is_a?(Hash)

      {}
    rescue Psych::SyntaxError => e
      raise ThemeManifestError, "#{path}: #{e.message}"
    end
  end
end
