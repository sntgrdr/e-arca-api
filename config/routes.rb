Rails.application.routes.draw do
  devise_for :users,
             path: 'api/v1/auth',
             path_names: {
               sign_in: 'sign_in',
               sign_out: 'sign_out',
               registration: 'sign_up'
             },
             controllers: {
               sessions: 'api/v1/auth/sessions',
               registrations: 'api/v1/auth/registrations'
             }

  namespace :api do
    namespace :v1 do
      # Profile
      get 'profile', to: 'profiles#show'
      patch 'profile', to: 'profiles#update'
      get 'profile/last_invoice', to: 'profiles#last_invoice'

      # Resources
      resources :clients
      resources :client_groups
      resources :items do
        collection { get :autocomplete }
      end
      resources :ivas
      resources :sell_points

      resources :client_invoices do
        collection { get :next_number }
        member do
          post :send_to_arca
          get :download_pdf
          get :history
        end
      end

      resources :credit_notes do
        collection { get :next_number }
        member { post :send_to_arca }
      end

      resources :batch_invoice_processes, only: [:index, :create, :show] do
        collection { get :last_invoice_date }
        member do
          post :generate_pdfs
          get :download_pdfs
        end
      end
    end
  end

  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'api/v1/health', to: 'api/v1/health#show'
end
