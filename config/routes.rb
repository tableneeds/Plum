Rails.application.routes.draw do
  # Auth
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Control Panel
  namespace :cp do
    root "dashboard#show"
    resources :content_types do
      resources :entries
    end
    resource :site_settings, only: [ :show, :edit, :update ]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  get "favicon.ico", to: redirect("/icon.svg")

  # Public Liquid-rendered pages (catch-all must be last)
  root "pages#home"
  get "*slug", to: "pages#show", constraints: ->(req) { !req.path.start_with?("/rails/") }
end
