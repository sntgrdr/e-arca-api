module Api
  module V1
    class BatchArcaProcessesController < BaseController
      before_action :set_batch, only: %i[show retry]

      def index
        batches = policy_scope(BatchArcaProcess).order(created_at: :desc)
        result  = pagination_result(batches)
        render_paginated(result, serializer: BatchArcaProcessSerializer)
      end

      def show
        authorize @batch
        render json: @batch, serializer: BatchArcaProcessDetailSerializer
      end

      def create
        authorize BatchArcaProcess

        result = BatchArca::CreateService.new(
          user:            current_user,
          invoice_ids:     batch_params[:invoice_ids],
          invoice_class:   batch_params[:invoice_class],
          idempotency_key: batch_params[:idempotency_key]
        ).call

        if result[:success]
          render json: result[:batch], serializer: BatchArcaProcessSerializer, status: :created
        else
          render json: { error: { code: "invalid_batch", message: result[:error] } },
                 status: :unprocessable_entity
        end
      end

      def retry
        authorize @batch, :retry?

        result = BatchArca::CreateService.new(
          user:            current_user,
          invoice_ids:     pending_invoice_ids_from(@batch),
          invoice_class:   @batch.invoice_class,
          idempotency_key: retry_params[:idempotency_key],
          parent_batch_id: @batch.id
        ).call

        if result[:success]
          render json: result[:batch], serializer: BatchArcaProcessSerializer, status: :created
        else
          render json: { error: { code: "invalid_retry", message: result[:error] } },
                 status: :unprocessable_entity
        end
      end

      private

      def set_batch
        @batch = BatchArcaProcess.find(params[:id])
      end

      def batch_params
        params.require(:batch_arca_process).permit(:invoice_class, :idempotency_key, invoice_ids: [])
      end

      def retry_params
        params.permit(:idempotency_key)
      end

      def pending_invoice_ids_from(batch)
        batch.batch_arca_process_invoices
             .where(arca_status: %w[failed blocked])
             .joins(:invoice)
             .order(Arel.sql("CAST(invoices.number AS INTEGER) ASC"))
             .pluck(:invoice_id)
      end
    end
  end
end
