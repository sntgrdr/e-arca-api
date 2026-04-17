module Api
  module V1
    class ClientsController < BaseController
      before_action :set_client, only: %i[show update destroy deactivate reactivate]

      def index
        base_scope = if params[:status] == "inactive"
          policy_scope(Client).where(active: false)
        else
          policy_scope(Client).active
        end
        base_scope = base_scope.includes(:iva, :client_group)
        filtered = ::Filters::ClientsFilterService.new(params, base_scope).call
        result = paginate(filtered)
        render_paginated(result, serializer: ClientSerializer)
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

      def deactivate
        authorize @client
        if @client[:final_client]
          return render json: { errors: [ I18n.t("clients.errors.cannot_deactivate_final_client") ] },
                        status: :unprocessable_entity
        end
        @client.update!(active: false)
        render json: @client, serializer: ClientSerializer
      end

      def reactivate
        authorize @client
        @client.update!(active: true)
        render json: @client, serializer: ClientSerializer
      end

      def search
        authorize Client, :search?
        clients = ClientsSearchQuery.call(q: params[:q], current_user: current_user, client_group_id: params[:client_group_id])
        render json: clients, each_serializer: ClientSearchSerializer, status: :ok
      end

      def bulk_deactivate
        authorize Client, :bulk_deactivate?
        ids = Array(params[:ids]).map(&:to_i)
        updated = Client.where(user_id: current_user.id, id: ids, final_client: false)
                        .update_all(active: false)
        render json: { deactivated: updated }
      end

      def bulk_reactivate
        authorize Client, :bulk_reactivate?
        ids = Array(params[:ids]).map(&:to_i)
        updated = Client.where(user_id: current_user.id, id: ids)
                        .update_all(active: true)
        render json: { reactivated: updated }
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
