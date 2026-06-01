module Plum
  class ThemeResolver
    def initialize(registry: ThemeRegistry.new, fallback_handle: ThemeRegistry::DEFAULT_THEME_HANDLE)
      @registry = registry
      @fallback_handle = fallback_handle
    end

    def theme(handle)
      registry.fetch(handle)
    end

    def find_template(theme_handle, template_name)
      template_candidates(theme_handle, template_name).find(&:file?)
    end

    def find_layout(theme_handle, layout_name = "base")
      themes_for(theme_handle).map { |theme| theme.layout_path(layout_name) }.find(&:file?)
    end

    def find_asset(theme_handle, asset_name)
      themes_for(theme_handle).filter_map { |theme| theme.asset_path(asset_name) }.find(&:file?)
    end

    private

    attr_reader :registry, :fallback_handle

    def template_candidates(theme_handle, template_name)
      themes_for(theme_handle).flat_map do |theme|
        paths = [ theme.template_path(template_name) ]
        paths << theme.template_path("entries/_default") if template_name.to_s.start_with?("entries/")
        paths << theme.template_path("collections/_default") if template_name.to_s.start_with?("collections/")
        paths << theme.template_path("taxonomies/_default") if template_name.to_s.start_with?("taxonomies/")
        paths
      end
    end

    def themes_for(theme_handle)
      theme_chain(theme_handle).uniq { |theme| theme.root.to_s }
    end

    def theme_chain(theme_handle)
      themes = []
      current_theme = registry.find(theme_handle) || registry.default_theme

      while current_theme && themes.none? { |theme| theme.handle == current_theme.handle }
        themes << current_theme
        current_theme = registry.find(current_theme.parent_handle)
      end

      themes << registry.find(fallback_handle)
      themes.compact
    end
  end
end
