require_relative "liquid_filters"

module Plum
  class LiquidRenderer
    class << self
      def render_template(template_name, context = {})
        theme = current_theme(context)
        resolver = ThemeResolver.new
        template_path = resolver.find_template(theme, template_name)

        raise "Template not found: #{template_name}" unless template_path

        template_content = File.read(template_path)
        template = Liquid::Template.parse(template_content)

        rendered_content = template.render(context, filters: [ LiquidFilters ])

        layout_path = resolver.find_layout(theme)
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
    end
  end
end
