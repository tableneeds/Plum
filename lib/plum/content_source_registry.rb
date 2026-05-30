require "date"
require_relative "content_source"
require_relative "content_source_context"

module Plum
  class ContentSourceRegistry
    RESERVED_HANDLES = %w[entry entries globals site].freeze
    HANDLE_PATTERN = /\A[a-z][a-z0-9_]*\z/

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

      @sources.each_with_object({}) do |(handle, source), hash|
        hash[handle] = resolve_source(handle, source, context)
      end
    end

    private

    def normalize_handle(handle)
      handle.to_s
    end

    def validate_handle!(handle)
      raise ArgumentError, "Content source handle cannot be blank" if handle.blank?
      unless handle.match?(HANDLE_PATTERN)
        raise ArgumentError, "Content source handle must use lowercase letters, numbers, and underscores"
      end

      if RESERVED_HANDLES.include?(handle)
        raise ArgumentError, "`#{handle}` is reserved by Plum's Liquid context"
      end
    end

    def resolve_source(handle, source, context)
      source = constantize_source(source)
      value =
        if source.respond_to?(:call)
          source.call(context)
        elsif source.respond_to?(:to_liquid)
          source.to_liquid
        elsif source.respond_to?(:new)
          adapter = source.new(context)
          unless adapter.respond_to?(:to_liquid)
            raise ContentSourceError, "adapter #{source.name || source.inspect} must implement #to_liquid"
          end

          adapter.to_liquid
        else
          source
        end

      normalize_for_liquid(value)
    rescue ContentSourceError
      raise
    rescue StandardError => e
      raise ContentSourceError, "Content source `#{handle}` failed: #{e.message}"
    end

    def constantize_source(source)
      return source unless source.is_a?(String)

      source.safe_constantize ||
        raise(ContentSourceError, "Content source adapter `#{source}` could not be found")
    end

    def normalize_for_liquid(value)
      case value
      when nil, String, Numeric, TrueClass, FalseClass, Date, Time
        value
      when Hash
        value.each_with_object({}) do |(key, child), hash|
          hash[key.to_s] = normalize_for_liquid(child)
        end
      when Array
        value.map { |child| normalize_for_liquid(child) }
      else
        normalize_object_for_liquid(value)
      end
    end

    def normalize_object_for_liquid(value)
      if value.respond_to?(:to_liquid)
        liquid_value = value.to_liquid
        return liquid_value if liquid_value.equal?(value)

        return normalize_for_liquid(liquid_value)
      end

      if value.respond_to?(:to_a) && !value.is_a?(String)
        return value.to_a.map { |child| normalize_for_liquid(child) }
      end

      raise ContentSourceError,
        "#{value.class.name} is not Liquid-safe. Return a Hash, Array, scalar, or object with #to_liquid."
    end
  end
end
