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
        resources :entries do
          patch :image_field, on: :member
        end
      end
      resources :assets, except: [ :show ]
      resources :globals
      resources :nav_menus do
        resources :nav_items, except: [ :index, :show ]
      end
      resources :form_definitions, path: "forms" do
        resources :form_submissions, only: [ :show, :destroy ]
      end
      resource :site_settings, only: [ :show, :edit, :update ]
      patch "site_settings/image_field", to: "site_settings#image_field", as: :site_settings_image_field
      resources :themes, only: [ :index, :create, :update ]
      resources :taxonomies do
        resources :terms, except: [ :index, :show ]
      end
      get "theme_previews/:handle", to: "theme_previews#show", as: :theme_preview
    end

    post "forms/:handle", to: "form_submissions#create", as: :form
    get "theme_assets/:theme_handle/*path", to: "theme_assets#show", as: :theme_asset, format: false

    get "search", to: "pages#search", as: :search

    root "pages#home"
    get "*slug", to: "pages#show", constraints: ->(req) { !req.path.start_with?("/rails/") }
  end
end
