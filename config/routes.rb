Rails.application.routes.draw do
  devise_for :users,
             path: "api/v1/auth",
             path_names: {
               sign_in: "sign_in",
               sign_out: "sign_out",
               registration: "sign_up"
             },
             controllers: {
               sessions: "api/v1/auth/sessions",
               registrations: "api/v1/auth/registrations"
             }

  namespace :api do
    namespace :v1 do
      # Profile
      get "profile", to: "profiles#show"
      patch "profile", to: "profiles#update"
      get "profile/last_invoice", to: "profiles#last_invoice"

      # Resources
      resources :clients do
        member do
          patch :deactivate
          patch :reactivate
        end
        collection do
          get   :search
          patch :bulk_deactivate
          patch :bulk_reactivate
          post  :bulk_destroy
        end
      end
      resources :client_groups do
        member do
          patch :deactivate
          patch :reactivate
        end
      end
      resources :item_groups do
        member do
          patch :deactivate
          patch :reactivate
        end
      end
      resources :items do
        member do
          patch :deactivate
          patch :reactivate
        end
        collection do
          get   :autocomplete
          post  :bulk_destroy
          patch :bulk_activate
          patch :bulk_deactivate
          patch :bulk_update_prices
        end
      end
      resources :ivas do
        member do
          patch :deactivate
          patch :reactivate
        end
      end
      resources :sell_points do
        member do
          patch :deactivate
          patch :reactivate
        end
      end

      resources :client_invoices do
        collection do
          get  :next_number
          post :bulk_destroy
        end
        member do
          post :send_to_arca
          get  :download_pdf
          get  :history
        end
      end

      resources :credit_notes do
        collection do
          get  :next_number
          get  :create_from_invoice
          post :bulk_destroy
        end
        member do
          post :send_to_arca
          get  :download_pdf
        end
      end

      resources :batch_invoice_processes, only: [ :index, :create, :show ] do
        collection { get :last_invoice_date }
        member do
          post :generate_pdfs
          get :download_pdfs
        end
      end

      resources :batch_arca_processes, only: %i[index create show] do
        member { post :retry }
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "api/v1/health", to: "api/v1/health#show"
end
