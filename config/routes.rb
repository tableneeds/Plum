Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show"
  get "favicon.ico", to: redirect("/icon.svg")

  scope module: "plum" do
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
