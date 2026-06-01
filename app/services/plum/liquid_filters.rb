require "redcarpet"

module Plum
  module LiquidFilters
    def markdown(input)
      return "" if input.blank?

      text = input.to_s
      return text if text.match?(/<[a-z][\s\S]*>/i)

      renderer = Redcarpet::Render::HTML.new(
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener" }
      )

      md = Redcarpet::Markdown.new(renderer,
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        superscript: true,
        no_intra_emphasis: true
      )

      md.render(text)
    end

    def theme_asset_url(input)
      builder = @context.registers[:theme_asset_url_builder]
      return "" unless builder

      builder.call(input)
    end
  end
end
