module Api
  module V1
    class ClientsController < BaseController
      before_action :set_client, only: %i[show update destroy]

      def index
        base_scope = policy_scope(Client).active.includes(:iva, :client_group)
        filtered = ::Filters::ClientsFilterService.new(params, base_scope).call
        result = paginate(filtered)
        render json: result[:data], meta: result[:pagination], each_serializer: ClientSerializer
      end

      def show
        authorize @client
        render json: @client, serializer: ClientSerializer
      end

      def create
        client = Client.new(client_params.merge(user_id: current_user.id))
        authorize client

        if client.save
          render json: client, serializer: ClientSerializer, status: :created
        else
          render_errors(client.errors.full_messages)
        end
      end

      def update
        authorize @client
        if @client.update(client_params)
          render json: @client, serializer: ClientSerializer
        else
          render_errors(@client.errors.full_messages)
        end
      end

      def destroy
        authorize @client
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
          :active, :iva_id, :client_group_id, :dni
        )
      end
    end
  end
end
