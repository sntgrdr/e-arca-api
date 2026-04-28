module Api
  module V1
    class IvasController < BaseController
      before_action :set_iva, only: %i[show update destroy deactivate reactivate]

      def index
        scope = params[:status] == "inactive" ? policy_scope(Iva).where(active: false) : policy_scope(Iva).active
        result = pagination_result(scope)
        render_paginated(result, serializer: IvaSerializer)
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

      def deactivate
        authorize @iva
        @iva.update!(active: false)
        render json: @iva, serializer: IvaSerializer
      end

      def reactivate
        authorize @iva
        @iva.update!(active: true)
        render json: @iva, serializer: IvaSerializer
      end

      private

      def set_iva
        @iva = Iva.where(user_id: current_user.id).find(params[:id])
      end

      def iva_params
        params.require(:iva).permit(:percentage, :name, :active)
      end
    end
  end
end
