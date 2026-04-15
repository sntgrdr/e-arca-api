module Api
  module V1
    class ClientGroupsController < BaseController
      before_action :set_client_group, only: %i[show update destroy]

      def index
        groups = policy_scope(ClientGroup).active
        render json: groups, each_serializer: ClientGroupSerializer
      end

      def show
        authorize @client_group
        render json: @client_group, serializer: ClientGroupSerializer
      end

      def create
        group = ClientGroup.new(client_group_params.merge(user_id: current_user.id))
        authorize group

        if group.save
          render json: group, serializer: ClientGroupSerializer, status: :created
        else
          render_errors(group.errors.full_messages)
        end
      end

      def update
        authorize @client_group
        if @client_group.update(client_group_params)
          render json: @client_group, serializer: ClientGroupSerializer
        else
          render_errors(@client_group.errors.full_messages)
        end
      end

      def destroy
        authorize @client_group
        @client_group.destroy!
        head :no_content
      end

      private

      def set_client_group
        @client_group = ClientGroup.where(user_id: current_user.id).find(params[:id])
      end

      def client_group_params
        params.require(:client_group).permit(:name, :active, :details)
      end
    end
  end
end
