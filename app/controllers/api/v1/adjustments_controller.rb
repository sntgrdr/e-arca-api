module Api
  module V1
    class AdjustmentsController < BaseController
      before_action :set_adjustment, only: %i[show update destroy deactivate reactivate]

      def index
        adjustments = policy_scope(Adjustment)
          .includes(:target, adjustment_applicables: :applicable)
        render json: { data: ActiveModelSerializers::SerializableResource.new(adjustments, each_serializer: AdjustmentSerializer) }
      end

      def show
        authorize @adjustment
        render json: @adjustment, serializer: AdjustmentSerializer
      end

      def create
        adjustment = Adjustment.new(adjustment_params.merge(user_id: current_user.id))
        authorize adjustment

        Adjustment.transaction do
          adjustment.save!
          build_applicables(adjustment)
        end

        render json: adjustment, serializer: AdjustmentSerializer, status: :created
      end

      def update
        authorize @adjustment

        Adjustment.transaction do
          @adjustment.update!(adjustment_params)
          if params.dig(:adjustment, :applicable_ids)
            @adjustment.adjustment_applicables.destroy_all
            build_applicables(@adjustment)
          end
        end

        render json: @adjustment, serializer: AdjustmentSerializer
      end

      def destroy
        authorize @adjustment
        @adjustment.discard
        head :no_content
      end

      def deactivate
        authorize @adjustment
        @adjustment.update!(active: false)
        render json: @adjustment, serializer: AdjustmentSerializer
      end

      def reactivate
        authorize @adjustment
        @adjustment.update!(active: true)
        render json: @adjustment, serializer: AdjustmentSerializer
      end

      def resolve
        authorize Adjustment, :resolve?
        client = Client.where(user_id: current_user.id).find(params[:client_id])
        item   = Item.where(user_id: current_user.id).find(params[:item_id])

        result = Adjustments::ResolveService.new(
          user:   current_user,
          client: client,
          item:   item,
          date:   Date.current
        ).call

        render json: {
          discount:  result[:discount]  ? AdjustmentSerializer.new(result[:discount],  root: false).as_json  : nil,
          surcharge: result[:surcharge] ? AdjustmentSerializer.new(result[:surcharge], root: false).as_json : nil
        }
      end

      private

      def set_adjustment
        @adjustment = Adjustment.kept
                                .where(user_id: current_user.id)
                                .includes(adjustment_applicables: :applicable)
                                .find(params[:id])
      end

      def adjustment_params
        params.require(:adjustment).permit(
          :adjustment_type, :calculation_type, :amount,
          :target_type, :target_id,
          :start_date, :end_date, :active
        )
      end

      def build_applicables(adjustment)
        applicable_ids  = Array(params.dig(:adjustment, :applicable_ids)).map(&:to_i).select(&:positive?)
        applicable_type = params.dig(:adjustment, :applicable_type).to_s

        return if applicable_ids.empty? || applicable_type.blank?

        applicable_ids.each do |id|
          adjustment.adjustment_applicables.create!(
            applicable_type: applicable_type,
            applicable_id:   id
          )
        end
      end
    end
  end
end
