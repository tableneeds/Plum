require "liquid"

module Plum
  # Renders an array of block instances (stored on an entry's blocks field) into
  # HTML using theme-provided Liquid block partials.
  #
  # Each block instance has the shape:
  #
  #   { "id" => "<uuid>", "type" => "hero", "fields" => { "heading" => "Hi", "image" => 42 } }
  #
  # A block's own field values are exposed to its partial under the `block`
  # variable, and the full shared site context (site, globals, nav, theme
  # settings, registered content sources, ...) is merged in so block partials see
  # exactly what a normal template sees. Image and relationship block fields are
  # expanded with the same rules as entry fields via FieldExpander.
  class BuilderRenderer
    def initialize(blocks:, base_assigns:, site:, theme:, field_expander: nil, registers: {})
      @blocks = Array(blocks)
      @base_assigns = base_assigns || {}
      @site = site
      @theme = theme
      @library = BlockLibrary.new(theme)
      @field_expander = field_expander || FieldExpander.new(site: site)
      @registers = registers
    end

    def render
      return "".html_safe if blocks.empty?

      rendered = blocks.filter_map { |block| render_block(block) }
      rendered.join("\n").html_safe
    end

    private

    attr_reader :blocks, :base_assigns, :site, :theme, :library, :field_expander, :registers

    def render_block(block)
      return unless block.is_a?(Hash)

      handle = block["type"].to_s
      definition = library.definition(handle)
      return debug_comment("unknown block type: #{handle}") if definition.nil?

      template_source = library.template(handle)
      return debug_comment("missing block template: #{handle}") if template_source.nil?

      template = Liquid::Template.parse(template_source)
      assigns = base_assigns.merge("block" => block_assigns(block, definition))
      template.render(assigns, filters: [ LiquidFilters ], registers: registers)
    end

    def block_assigns(block, definition)
      field_expander.expand(values: block["fields"], fields: definition["fields"])
    end

    def debug_comment(message)
      return "" unless defined?(Rails) && Rails.env.development?

      "<!-- plum block: #{ERB::Util.html_escape(message)} -->"
    end
  end
end
