module Plum
  module LiquidFilters
    def markdown(input)
      return "" if input.blank?

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

      md.render(input.to_s)
    end
  end
end
