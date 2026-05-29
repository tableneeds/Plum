module Plum
  class ContentSourceRegistry
    def initialize
      @sources = {}
    end

    def register(handle, source)
      @sources[handle.to_s] = source
    end

    def to_liquid_context(controller)
      @sources.transform_values do |source|
        resolve_source(source, controller)
      end
    end

    private

    def resolve_source(source, controller)
      return source.call(controller) if source.respond_to?(:call)
      return source.new(controller).to_liquid if source.respond_to?(:new)

      source
    end
  end
end
