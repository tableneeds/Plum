require_relative "content_source_context"

module Plum
  class ContentSourceRegistry
    RESERVED_HANDLES = %w[entry entries globals site].freeze

    def initialize
      @sources = {}
    end

    def register(handle, source = nil, &block)
      raise ArgumentError, "Provide a source or a block, not both" if source && block
      raise ArgumentError, "Content source is required" unless source || block

      normalized_handle = normalize_handle(handle)
      validate_handle!(normalized_handle)

      @sources[normalized_handle] = source || block
    end

    def handles
      @sources.keys
    end

    def clear
      @sources.clear
    end

    def to_liquid_context(controller:, site:)
      context = ContentSourceContext.new(controller: controller, site: site)

      @sources.transform_values do |source|
        resolve_source(source, context)
      end
    end

    private

    def normalize_handle(handle)
      handle.to_s
    end

    def validate_handle!(handle)
      raise ArgumentError, "Content source handle cannot be blank" if handle.blank?

      if RESERVED_HANDLES.include?(handle)
        raise ArgumentError, "`#{handle}` is reserved by Plum's Liquid context"
      end
    end

    def resolve_source(source, context)
      source = constantize_source(source)

      return source.call(context) if source.respond_to?(:call)
      return source.to_liquid if source.respond_to?(:to_liquid)
      return source.new(context).to_liquid if source.respond_to?(:new)

      source
    end

    def constantize_source(source)
      return source unless source.is_a?(String)

      source.safe_constantize || source
    end
  end
end
