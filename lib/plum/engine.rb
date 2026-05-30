require_relative "configuration"

module Plum
  class Engine < ::Rails::Engine
    isolate_namespace Plum
    config.paths["config/routes.rb"] = []
    config.paths["db/migrate"] = []

    routes.draw do
      get "login", to: "sessions#new"
      post "login", to: "sessions#create"
      delete "logout", to: "sessions#destroy"

      namespace :cp do
        root "dashboard#show"
        resources :content_types do
          resources :entries
        end
        resource :site_settings, only: [ :show, :edit, :update ]
      end

      root "pages#home"
      get "*slug", to: "pages#show", constraints: ->(req) { !req.path.start_with?("/rails/") }
    end
  end
end
