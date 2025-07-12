Rails.application.routes.draw do
  # Authentication
  devise_for :users

  # Root route
  root "home#index"

  # Main application routes
  resources :trips do
    member do
      patch :update_status
      get :latest_route
      post :optimize_route
    end

    resources :chat_sessions, only: [:show, :create] do
      member do
        post :create_message
      end
    end
  end

  # Health check for deployment
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA routes (for future mobile support)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
