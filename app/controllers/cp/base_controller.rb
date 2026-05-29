module Cp
  class BaseController < ApplicationController
    layout "cp"
    before_action :require_login

    private

    def require_login
      unless logged_in?
        redirect_to login_path, alert: "Please log in to continue"
      end
    end
  end
end
