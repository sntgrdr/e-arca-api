module Api
  module V1
    class SellPointsController < BaseController
      before_action :set_sell_point, only: %i[show update destroy]

      def index
        result = paginate(policy_scope(SellPoint).active)
        render_paginated(result, serializer: SellPointSerializer)
      end

      def show
        authorize @sell_point
        render json: @sell_point, serializer: SellPointSerializer
      end

      def create
        sell_point = SellPoint.new(sell_point_params.merge(user_id: current_user.id))
        authorize sell_point

        if sell_point.save
          render json: sell_point, serializer: SellPointSerializer, status: :created
        else
          render_errors(sell_point.errors.full_messages)
        end
      end

      def update
        authorize @sell_point
        if @sell_point.update(sell_point_params)
          render json: @sell_point, serializer: SellPointSerializer
        else
          render_errors(@sell_point.errors.full_messages)
        end
      end

      def destroy
        authorize @sell_point
        if @sell_point.destroy
          head :no_content
        else
          render_errors(@sell_point.errors.full_messages)
        end
      end

      private

      def set_sell_point
        @sell_point = SellPoint.where(user_id: current_user.id).find(params[:id])
      end

      def sell_point_params
        params.require(:sell_point).permit(:number, :name, :active, :default)
      end
    end
  end
end
