module Api
  module V1
    class ClientsController < BaseController
      before_action :set_client, only: %i[show update destroy]

      def index
        base_scope = Client.all_my_clients(current_user.id).active
        filtered = ::Filters::ClientsFilterService.new(params, base_scope).call
        result = paginate(filtered)
        render json: result[:data], meta: result[:pagination], each_serializer: ClientSerializer
      end

      def show
        render json: @client, serializer: ClientSerializer
      end

      def create
        client = Client.new(client_params.merge(user_id: current_user.id))

        if client.save
          render json: client, serializer: ClientSerializer, status: :created
        else
          render_errors(client.errors.full_messages)
        end
      end

      def update
        if @client.update(client_params)
          render json: @client, serializer: ClientSerializer
        else
          render_errors(@client.errors.full_messages)
        end
      end

      def destroy
        @client.destroy!
        head :no_content
      end

      private

      def set_client
        @client = Client.where(user_id: current_user.id).find(params[:id])
      end

      def client_params
        params.require(:client).permit(
          :legal_name, :legal_number, :tax_condition, :name,
          :active, :iva_id, :client_group_id
        )
      end
    end
  end
end
