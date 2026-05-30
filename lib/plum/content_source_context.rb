module Plum
  class ContentSourceContext
    attr_reader :controller, :site

    def initialize(controller:, site:)
      @controller = controller
      @site = site
    end

    def request
      controller.request
    end

    def params
      controller.params
    end

    def session
      controller.session
    end

    def current_user
      controller.send(:current_user) if controller.respond_to?(:current_user, true)
    end

    def owner
      site.owner if site.respond_to?(:owner)
    end
  end
end
