module Api
  module V1
    class IvasController < BaseController
      before_action :set_iva, only: %i[show update destroy]

      def index
        ivas = policy_scope(Iva).active
        render json: ivas, each_serializer: IvaSerializer
      end

      def show
        authorize @iva
        render json: @iva, serializer: IvaSerializer
      end

      def create
        iva = Iva.new(iva_params.merge(user_id: current_user.id))
        authorize iva

        if iva.save
          render json: iva, serializer: IvaSerializer, status: :created
        else
          render_errors(iva.errors.full_messages)
        end
      end

      def update
        authorize @iva
        if @iva.update(iva_params)
          render json: @iva, serializer: IvaSerializer
        else
          render_errors(@iva.errors.full_messages)
        end
      end

      def destroy
        authorize @iva
        @iva.destroy!
        head :no_content
      end

      private

      def set_iva
        @iva = Iva.where(user_id: current_user.id).find(params[:id])
      end

      def iva_params
        params.require(:iva).permit(:percentage, :name)
      end
    end
  end
end
