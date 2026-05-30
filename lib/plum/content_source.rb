module Plum
  class ContentSourceError < StandardError; end

  class ContentSource
    attr_reader :context

    def initialize(context)
      @context = context
    end

    def to_liquid
      raise ContentSourceError, "#{self.class.name} must implement #to_liquid"
    end

    private

    def controller
      context.controller
    end

    def site
      context.site
    end

    def owner
      context.owner
    end

    def request
      context.request
    end

    def params
      context.params
    end

    def session
      context.session
    end

    def current_user
      context.current_user
    end
  end
end
