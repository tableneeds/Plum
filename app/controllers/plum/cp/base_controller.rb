module Plum
  module Cp
    class BaseController < Plum::ApplicationController
      layout "plum/cp"
      before_action :require_login

      private

      def require_login
        return if Plum.authorized?(self)

        if Plum.configuration.authorize_with == :plum
          redirect_to login_path, alert: "Please log in to continue"
        else
          head :forbidden
        end
      end
    end
  end
end
