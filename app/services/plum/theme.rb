module Plum
  class Theme
    SUPPORTED_SETTING_TYPES = %w[text textarea color boolean select].freeze

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

    def category
      manifest["category"].presence
    end

    def screenshot_path
      path = normalize_asset_reference(manifest["screenshot"])
      return if path.blank?

      asset_path(path)&.file? ? path : nil
    end

    def parent_handle
      manifest["extends"].presence || manifest["parent"].presence
    end

    def settings_fields
      Array(manifest.dig("settings", "fields")).filter_map do |field|
        normalize_setting_field(field)
      end
    end

    def blocks
      Array(manifest["blocks"]).filter_map do |block|
        normalize_block_definition(block)
      end
    end

    def block_definition(handle)
      handle = handle.to_s
      return if handle.blank?

      blocks.find { |block| block["handle"] == handle }
    end

    def block_template(handle, variant: :web)
      path = block_template_path(handle, variant: variant)
      return unless path&.file?

      path.read
    end

    def block_template_path(handle, variant: :web)
      return unless variant.to_sym == :web

      normalized_handle = handle.to_s
      return if normalized_handle.blank? || !normalized_handle.match?(/\A[a-z][a-z0-9_]*\z/)

      root.join("blocks", "#{normalized_handle}.liquid")
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

    private

    def normalize_asset_reference(asset_name)
      raw_name = asset_name.to_s
      return if raw_name.blank?

      raw_name = raw_name.delete_prefix("assets/")
      ThemeAssetPath.normalize(raw_name)
    rescue ThemeAssetPath::UnsafePathError
      nil
    end

    def normalize_setting_field(field)
      return unless field.respond_to?(:to_h)

      normalized = field.to_h.deep_stringify_keys
      handle = normalized["handle"].to_s
      return if handle.blank?

      type = normalized["type"].presence || "text"
      type = "text" unless SUPPORTED_SETTING_TYPES.include?(type)

      normalized.merge(
        "handle" => handle,
        "type" => type,
        "label" => normalized["label"].presence || handle.humanize
      )
    end

    def normalize_block_definition(block)
      return unless block.respond_to?(:to_h)

      normalized = block.to_h.deep_stringify_keys
      handle = normalized["handle"].to_s
      return if handle.blank?

      normalized.merge(
        "handle" => handle,
        "label" => normalized["label"].presence || handle.humanize,
        "fields" => Array(normalized["fields"]).filter_map { |field| normalize_block_field(field) }
      )
    end

    def normalize_block_field(field)
      return unless field.respond_to?(:to_h)

      normalized = field.to_h.deep_stringify_keys
      handle = normalized["handle"].to_s
      return if handle.blank?

      normalized.merge(
        "handle" => handle,
        "type" => normalized["type"].presence || "text",
        "label" => normalized["label"].presence || handle.humanize
      )
    end
  end
end
