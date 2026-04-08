module Api
  module V1
    class ProfilesController < BaseController
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
        result = Invoices::Production::LastInvoiceQueryService.new(
          sell_point_number: params[:sell_point_number],
          afip_code:         params[:afip_code],
          user:              current_user
        ).call

        if result[:success]
          render json: { last_number: result[:last_number] }
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def user_params
        params.require(:user).permit(
          :name, :email, :legal_name, :legal_number, :tax_condition,
          :alias_account, :account_number, :address, :zip_code,
          :city, :state, :country, :cai, :activity_start, :active,
          :password, :password_confirmation
        )
      end
    end
  end
end
