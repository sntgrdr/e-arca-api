module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              message: "Cuenta creada correctamente.",
              user: ActiveModelSerializers::SerializableResource.new(resource, serializer: UserSerializer)
            }, status: :created
          else
            render json: {
              errors: resource.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def sign_up_params
          params.require(:user).permit(
            :email, :password, :password_confirmation,
            :legal_name, :legal_number, :name,
            :tax_condition, :alias_account, :account_number,
            :address, :zip_code, :city, :state, :country,
            :cai, :activity_start
          )
        end
      end
    end
  end
end
