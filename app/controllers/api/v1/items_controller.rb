module Api
  module V1
    class ItemsController < BaseController
      before_action :set_item, only: %i[show update destroy deactivate reactivate]

      def index
        base_scope = if params[:status] == "inactive"
          policy_scope(Item).where(active: false)
        else
          policy_scope(Item).active
        end
        filtered = ::Filters::ItemsFilterService.new(params, base_scope).call
        result = pagination_result(filtered)
        render_paginated(result, serializer: ItemSerializer)
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

      def deactivate
        authorize @item
        @item.update!(active: false)
        render json: @item, serializer: ItemSerializer
      end

      def reactivate
        authorize @item
        @item.update!(active: true)
        render json: @item, serializer: ItemSerializer
      end

      def bulk_destroy
        authorize Item, :bulk_destroy?
        ids = bulk_ids_param
        return render_bulk_ids_error if ids.nil?

        scope = policy_scope(Item)
        result = ::Bulk::DestroyItemsService.new(scope: scope, ids: ids).call
        render json: result
      end

      def bulk_activate
        authorize Item, :bulk_activate?
        ids = bulk_ids_param
        return render_bulk_ids_error if ids.nil?

        scope = policy_scope(Item)
        result = ::Bulk::ActivateItemsService.new(scope: scope, ids: ids).call
        render json: result
      end

      def bulk_deactivate
        authorize Item, :bulk_deactivate?
        ids = bulk_ids_param
        return render_bulk_ids_error if ids.nil?

        scope = policy_scope(Item)
        result = ::Bulk::DeactivateItemsService.new(scope: scope, ids: ids).call
        render json: result
      end

      def bulk_update_prices
        authorize Item, :bulk_update_prices?
        items_data = Array.wrap(params[:items]).map do |item_param|
          item_param.permit(:id, :price).to_h.symbolize_keys
        end

        scope  = policy_scope(Item).active
        result = Items::BulkUpdatePricesService.new(scope: scope, items_data: items_data).call

        if result[:success]
          render json: result[:items], each_serializer: ItemSerializer
        else
          render json: { error: { code: "validation_error", message: result[:error] } }, status: :unprocessable_entity
        end
      end

      def autocomplete
        authorize Item
        items = Item.all_my_items(current_user.id).active
                    .where("name ILIKE ? OR code ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
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
        params.require(:item).permit(:code, :name, :price, :iva_id, :item_group_id, :active)
      end
    end
  end
end
