module Api
  module V1
    class ItemGroupsController < BaseController
      before_action :set_item_group, only: %i[show update destroy]

      def index
        groups = policy_scope(ItemGroup).active
        render json: groups, each_serializer: ItemGroupSerializer
      end

      def show
        authorize @item_group
        render json: @item_group, serializer: ItemGroupSerializer
      end

      def create
        group = ItemGroup.new(item_group_params.merge(user_id: current_user.id))
        authorize group

        if group.save
          render json: group, serializer: ItemGroupSerializer, status: :created
        else
          render_errors(group.errors.full_messages)
        end
      end

      def update
        authorize @item_group
        if @item_group.update(item_group_params)
          render json: @item_group, serializer: ItemGroupSerializer
        else
          render_errors(@item_group.errors.full_messages)
        end
      end

      def destroy
        authorize @item_group
        @item_group.destroy!
        head :no_content
      end

      private

      def set_item_group
        @item_group = ItemGroup.where(user_id: current_user.id).find(params[:id])
      end

      def item_group_params
        params.require(:item_group).permit(:name, :active, :details)
      end
    end
  end
end
