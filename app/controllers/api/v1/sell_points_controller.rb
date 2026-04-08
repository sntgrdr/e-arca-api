module Api
  module V1
    class SellPointsController < BaseController
      before_action :set_sell_point, only: %i[show update destroy]

      def index
        sell_points = SellPoint.all_my_sell_points(current_user.id).active
        render json: sell_points, each_serializer: SellPointSerializer
      end

      def show
        render json: @sell_point, serializer: SellPointSerializer
      end

      def create
        sell_point = SellPoint.new(sell_point_params.merge(user_id: current_user.id))

        if sell_point.save
          render json: sell_point, serializer: SellPointSerializer, status: :created
        else
          render_errors(sell_point.errors.full_messages)
        end
      end

      def update
        if @sell_point.update(sell_point_params)
          render json: @sell_point, serializer: SellPointSerializer
        else
          render_errors(@sell_point.errors.full_messages)
        end
      end

      def destroy
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
