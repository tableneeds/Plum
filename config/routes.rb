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
        post :apply_fieldset, on: :member
        resources :entries do
          patch :image_field, on: :member
          get :write, on: :member
          get :diff, on: :member
          post :publish_draft, on: :member
          delete :discard_draft, on: :member
          post :translate, on: :member
          resources :revisions, controller: "entry_revisions", only: [ :index ] do
            post :restore, on: :member
          end
        end
      end
      resources :fieldsets, only: [ :index, :create, :destroy ]
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
      delete "static_cache", to: "static_cache#destroy", as: :static_cache
      resources :taxonomies do
        resources :terms, except: [ :index, :show ]
      end
      get "theme_previews/:handle", to: "theme_previews#show", as: :theme_preview
    end

    post "forms/:handle", to: "form_submissions#create", as: :form
    namespace :api do
      namespace :v1 do
        get "collections/:collection_handle/entries", to: "entries#index", as: :collection_entries
        get "collections/:collection_handle/entries/:slug", to: "entries#show", as: :collection_entry
      end
    end
    get "theme_assets/:theme_handle/*path", to: "theme_assets#show", as: :theme_asset, format: false

    get "search", to: "pages#search", as: :search

    get ":locale", to: "pages#localized_home", constraints: { locale: /[a-z]{2}(?:-[A-Z]{2})?/ }, as: :localized_root
    get ":locale/*slug", to: "pages#show", constraints: { locale: /[a-z]{2}(?:-[A-Z]{2})?/ }, as: :localized_page

    root "pages#home"
    get "*slug", to: "pages#show", constraints: ->(req) { !req.path.start_with?("/rails/") }
  end
end
