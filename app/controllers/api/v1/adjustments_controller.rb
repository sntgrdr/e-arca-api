module Api
  module V1
    class AdjustmentsController < BaseController
      before_action :require_adjustments_enabled!
      before_action :set_adjustment, only: %i[show update destroy deactivate reactivate]

      TARGET_TYPE_MODELS     = { "Client" => Client, "ClientGroup" => ClientGroup }.freeze
      APPLICABLE_TYPE_MODELS = { "Item" => Item, "ItemGroup" => ItemGroup }.freeze

      def index
        adjustments = policy_scope(Adjustment)
          .includes(:target, :iva, adjustment_applicables: :applicable)
        result = pagination_result(adjustments)
        render_paginated(result, serializer: AdjustmentSerializer)
      end

      def show
        authorize @adjustment
        render json: @adjustment, serializer: AdjustmentSerializer
      end

      def create
        target = find_verified_target
        return render_errors("target no encontrado", :not_found) unless target

        adjustment = Adjustment.new(
          adjustment_params.merge(user_id: current_user.id, target: target)
        )
        authorize adjustment

        applicable_ids, applicable_type = extract_applicables
        return render_errors("applicable_type inválido", :unprocessable_entity) if applicable_type.present? && APPLICABLE_TYPE_MODELS.exclude?(applicable_type)

        verified_ids = verify_applicable_ids(applicable_ids, applicable_type)
        return render_errors("uno o más applicables no encontrados", :not_found) if verified_ids.nil?

        if adjustment.calculation_type == "fixed"
          error = resolve_iva_for_fixed(adjustment, verified_ids, applicable_type)
          return render_errors(error, :unprocessable_entity) if error
        end

        Adjustment.transaction do
          adjustment.save!
          build_applicables(adjustment, verified_ids, applicable_type)
        end

        render json: adjustment.reload, serializer: AdjustmentSerializer, status: :created
      end

      def update
        authorize @adjustment

        new_applicable_ids = nil
        new_applicable_type = nil

        if params.dig(:adjustment, :applicable_type).present? && Array(params.dig(:adjustment, :applicable_ids)).any?
          new_applicable_ids, new_applicable_type = extract_applicables
          unless APPLICABLE_TYPE_MODELS.key?(new_applicable_type)
            return render_errors("applicable_type inválido", :unprocessable_entity)
          end

          new_applicable_ids = verify_applicable_ids(new_applicable_ids, new_applicable_type)
          return render_errors("uno o más applicables no encontrados", :not_found) if new_applicable_ids.nil?
        end

        @adjustment.assign_attributes(adjustment_params)

        if @adjustment.calculation_type == "fixed" && (new_applicable_ids || params.dig(:adjustment, :amount))
          item_ids = new_applicable_ids || @adjustment.adjustment_applicables.where(applicable_type: "Item").pluck(:applicable_id)
          error = resolve_iva_for_fixed(@adjustment, item_ids, "Item")
          return render_errors(error, :unprocessable_entity) if error
        end

        Adjustment.transaction do
          @adjustment.save!

          if new_applicable_ids
            @adjustment.adjustment_applicables.destroy_all
            build_applicables(@adjustment, new_applicable_ids, new_applicable_type)
          end
        end

        render json: @adjustment.reload, serializer: AdjustmentSerializer
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
        date   = params[:date].present? ? Date.parse(params[:date]) : Date.current

        result = Adjustments::ResolveService.new(
          user:   current_user,
          client: client,
          item:   item,
          date:   date
        ).call

        render json: {
          discount:  result[:discount]  ? AdjustmentSerializer.new(result[:discount],  root: false).as_json : nil,
          surcharge: result[:surcharge] ? AdjustmentSerializer.new(result[:surcharge], root: false).as_json : nil
        }
      end

      private

      def require_adjustments_enabled!
        return if current_user.adjustments_enabled?

        render json: { error: { code: "feature_disabled", message: "Esta función no está habilitada para tu cuenta." } },
               status: :forbidden
      end

      def set_adjustment
        @adjustment = Adjustment.kept
                                .where(user_id: current_user.id)
                                .includes(:iva, adjustment_applicables: :applicable)
                                .find(params[:id])
      end

      def adjustment_params
        params.require(:adjustment).permit(
          :adjustment_type, :calculation_type, :amount,
          :start_date, :end_date, :active
        )
      end

      def find_verified_target
        target_type = params.dig(:adjustment, :target_type).to_s
        target_id   = params.dig(:adjustment, :target_id).to_i
        model       = TARGET_TYPE_MODELS[target_type]
        return nil unless model && target_id.positive?

        model.where(user_id: current_user.id).find_by(id: target_id)
      end

      def extract_applicables
        ids  = Array(params.dig(:adjustment, :applicable_ids)).map(&:to_i).select(&:positive?)
        type = params.dig(:adjustment, :applicable_type).to_s.presence
        [ ids, type ]
      end

      def verify_applicable_ids(ids, type)
        return [] if ids.empty? || type.blank?

        model     = APPLICABLE_TYPE_MODELS[type]
        return nil unless model

        owner_col = model.column_names.include?("user_id") ? :user_id : nil
        scope     = owner_col ? model.where(owner_col => current_user.id) : model.all
        found     = scope.where(id: ids).pluck(:id)

        found.sort == ids.sort ? found : nil
      end

      def resolve_iva_for_fixed(adjustment, item_ids, applicable_type)
        return nil if item_ids.blank? || applicable_type != "Item"

        items   = Item.where(user_id: current_user.id).includes(:iva).where(id: item_ids)
        iva_ids = items.map(&:iva_id).uniq

        if iva_ids.size > 1
          return "Todos los ítems de un ajuste de monto fijo deben tener el mismo IVA"
        end

        iva = items.first&.iva
        adjustment.iva_id = iva&.id

        if iva&.percentage.to_f > 0
          adjustment.amount = (adjustment.amount.to_d / (1 + iva.percentage / 100.0)).round(4)
        end

        nil
      end

      def build_applicables(adjustment, ids, type)
        return if ids.empty? || type.blank?

        ids.each do |id|
          adjustment.adjustment_applicables.create!(
            applicable_type: type,
            applicable_id:   id
          )
        end
      end
    end
  end
end
