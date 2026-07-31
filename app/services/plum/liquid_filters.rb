require "redcarpet"
require "nokogiri"

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

    def image_url(input, size = nil)
      return "" if input.blank?
      return input["url"].to_s unless size && input.is_a?(Hash)

      input[size].presence || input["url"].to_s
    end

    def theme_asset_url(input)
      builder = @context.registers[:theme_asset_url_builder]
      return "" unless builder

      builder.call(input)
    end

    def table_of_contents(input)
      return "" if input.blank?

      headings = Nokogiri::HTML.fragment(input.to_s).css("h2, h3")
      return "" if headings.empty?

      items = headings.map do |heading|
        id = heading["id"].presence || heading.text.parameterize
        label = ERB::Util.html_escape(heading.text)
        %(<li class="toc-#{heading.name}"><a href="##{id}">#{label}</a></li>)
      end

      %(<nav class="table-of-contents" aria-label="On this page"><p>On this page</p><ol>#{items.join}</ol></nav>)
    end
  end
end
