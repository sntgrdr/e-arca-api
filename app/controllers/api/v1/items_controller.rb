module Api
  module V1
    class ItemsController < BaseController
      before_action :set_item, only: %i[show update destroy]

      def index
        base_scope = policy_scope(Item).active
        filtered = ::Filters::ItemsFilterService.new(params, base_scope).call
        result = paginate(filtered)
        render json: result[:data], meta: result[:pagination], each_serializer: ItemSerializer
      end

      def show
        authorize @item
        render json: @item, serializer: ItemSerializer
      end

      def create
        item = Item.new(item_params.merge(user_id: current_user.id))
        authorize item

        if item.save
          render json: item, serializer: ItemSerializer, status: :created
        else
          render_errors(item.errors.full_messages)
        end
      end

      def update
        authorize @item
        if @item.update(item_params)
          render json: @item, serializer: ItemSerializer
        else
          render_errors(@item.errors.full_messages)
        end
      end

      def destroy
        authorize @item
        @item.destroy!
        head :no_content
      end

      def autocomplete
        authorize Item
        items = Item.all_my_items(current_user.id).active
                    .where('name ILIKE ? OR code ILIKE ?', "%#{params[:q]}%", "%#{params[:q]}%")
                    .limit(10)

        render json: items.map { |item|
          {
            id: item.id,
            name: item.name,
            unit_price: item.price,
            iva_percentage: item.iva.percentage
          }
        }
      end

      private

      def set_item
        @item = Item.where(user_id: current_user.id).find(params[:id])
      end

      def item_params
        params.require(:item).permit(:code, :name, :price, :iva_id)
      end
    end
  end
end
