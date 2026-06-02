module Plum
  module Cp
    class BaseController < Plum::ApplicationController
      layout "plum/cp"
      helper AssetsHelper
      helper ThemeSettingsHelper

      before_action :require_login
      helper_method :cp_prefix

      private

      def cp_prefix
        @cp_prefix ||= cp_root_path.chomp("/")
      end

      def require_login
        return if Plum.authorized?(self)

        if Plum.configuration.authorize_with == :plum
          redirect_to login_path, alert: "Please log in to continue"
        else
          head :forbidden
        end
      end

      def require_role(*roles)
        return unless Plum.configuration.authorize_with == :plum

        user = Plum.current_user(self)
        return if user&.respond_to?(:role) && roles.map(&:to_s).include?(user.role.to_s)

        redirect_to cp_root_path, alert: "You don't have permission to do that"
      end

      def require_editor
        require_role(:editor, :admin)
      end

      def require_admin
        require_role(:admin)
      end
    end
  end
end
