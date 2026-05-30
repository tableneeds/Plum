module Plum
  module LiquidTags
    class FormTag < Liquid::Tag
      def initialize(tag_name, markup, options)
        super
        @handle_expression = Liquid::Expression.parse(markup.strip)
      end

      def render(context)
        handle = context.evaluate(@handle_expression).to_s
        renderer = context.registers[:form_renderer]

        renderer ? renderer.call(handle) : ""
      end
    end
  end
end
