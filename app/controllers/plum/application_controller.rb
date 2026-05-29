module Plum
  class ApplicationController < ::ApplicationController
    helper Rails.application.routes.url_helpers
    helper_method :current_site, :current_user, :logged_in?

    private

    def current_site
      @current_site ||= Plum.current_site(self)
    end

    def current_user
      @current_user ||= Plum.current_user(self)
    end

    def logged_in?
      current_user.present?
    end
  end
end
