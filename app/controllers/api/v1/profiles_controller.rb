module Api
  module V1
    class ProfilesController < BaseController
      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      def show
        render json: current_user, serializer: UserSerializer
      end

      def update
        if current_user.update(user_params)
          render json: current_user, serializer: UserSerializer
        else
          render_errors(current_user.errors.full_messages)
        end
      end

      def last_invoice
        result = arca_service_module::LastInvoiceQueryService.new(
          sell_point_number: params[:sell_point_number],
          afip_code:         params[:afip_code],
          user:              current_user
        ).call

        if result[:success]
          render json: {
            last_number: result[:last_number],
            afip_authorized_at: result[:afip_authorized_at]
          }
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error("[ProfilesController#last_invoice] #{e.class}: #{e.message}")
        render json: { error: { code: "service_error", message: "Could not retrieve last invoice from AFIP" } }, status: :unprocessable_entity
      end

      private

      def user_params
        params.require(:user).permit(
          :name, :email, :legal_name, :legal_number, :dni, :tax_condition,
          :alias_account, :account_number, :address, :zip_code,
          :city, :state, :country, :cai, :activity_start, :active,
          :password, :password_confirmation
        )
      end
    end
  end
end
