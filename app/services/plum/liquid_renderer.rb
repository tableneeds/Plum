require_relative "liquid_filters"

module Plum
  class LiquidRenderer
    THEMES_PATH = Rails.root.join("app/themes")

    class << self
      def render_template(template_name, context = {})
        theme = current_theme(context)
        template_path = find_template(theme, template_name)

        raise "Template not found: #{template_name}" unless template_path

        template_content = File.read(template_path)
        template = Liquid::Template.parse(template_content)

        rendered_content = template.render(context, filters: [ LiquidFilters ])

        layout_path = find_layout(theme)
        if layout_path
          layout_content = File.read(layout_path)
          layout = Liquid::Template.parse(layout_content)
          layout.render(context.merge("content" => rendered_content), filters: [ LiquidFilters ])
        else
          rendered_content
        end
      end

      private

      def current_theme(context)
        context.dig("site", "theme_name").presence || "default"
      end

      def find_template(theme, template_name)
        paths = [
          THEMES_PATH.join(theme, "templates", "#{template_name}.liquid"),
          THEMES_PATH.join(theme, "templates", "entries", "_default.liquid"),
          THEMES_PATH.join("default", "templates", "#{template_name}.liquid"),
          THEMES_PATH.join("default", "templates", "entries", "_default.liquid")
        ]

        paths.find { |path| File.exist?(path) }
      end

      def find_layout(theme)
        paths = [
          THEMES_PATH.join(theme, "layouts", "base.liquid"),
          THEMES_PATH.join("default", "layouts", "base.liquid")
        ]

        paths.find { |path| File.exist?(path) }
      end
    end
  end
end
