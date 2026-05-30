module Plum
  class ApplicationController < ::ApplicationController
    helper_method :current_site, :current_user, :current_user_label, :logged_in?, :plum_managed_auth?

    private

    def current_site
      @current_site ||= Plum.current_site(self)
    end

    def current_user
      @current_user ||= Plum.current_user(self)
    end

    def current_user_label
      user = current_user

      return user.email if user.respond_to?(:email) && user.email.present?
      return user.name if user.respond_to?(:name) && user.name.present?

      "Account"
    end

    def logged_in?
      current_user.present?
    end

    def plum_managed_auth?
      Plum.configuration.authorize_with == :plum
    end
  end
end
