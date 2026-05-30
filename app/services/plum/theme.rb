module Plum
  class Theme
    attr_reader :handle, :root, :manifest

    def initialize(root:, manifest: {})
      @root = Pathname(root)
      @manifest = manifest.to_h.deep_stringify_keys
      @handle = @manifest["handle"].presence || @root.basename.to_s
    end

    def name
      manifest["name"].presence || handle.titleize
    end

    def version
      manifest["version"].presence
    end

    def author
      manifest["author"].presence
    end

    def description
      manifest["description"].presence
    end

    def parent_handle
      manifest["extends"].presence || manifest["parent"].presence
    end

    def settings_fields
      Array(manifest.dig("settings", "fields"))
    end

    def asset_root
      root.join("assets")
    end

    def asset_path(asset_name)
      normalized_name = ThemeAssetPath.normalize(asset_name)
      candidate = asset_root.join(normalized_name).expand_path
      expanded_asset_root = asset_root.expand_path

      return unless candidate.to_s.start_with?("#{expanded_asset_root}/")

      candidate
    rescue ThemeAssetPath::UnsafePathError
      nil
    end

    def template_path(template_name)
      root.join("templates", "#{template_name}.liquid")
    end

    def layout_path(layout_name = "base")
      root.join("layouts", "#{layout_name}.liquid")
    end
  end
end
