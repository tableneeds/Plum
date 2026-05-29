module Plum
  class SessionsController < ApplicationController
    layout "plum/session"

    def new
      redirect_to cp_root_path if logged_in?
    end

    def create
      user = Plum::User.find_by(email: params[:email])
      if user&.authenticate(params[:password])
        session[:plum_user_id] = user.id
        redirect_to cp_root_path, notice: "Welcome back!"
      else
        flash.now[:alert] = "Invalid email or password"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session[:plum_user_id] = nil
      redirect_to login_path, notice: "You have been logged out"
    end
  end
end
