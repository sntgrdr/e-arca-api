module Api
  module V1
    class BatchArcaProcessesController < BaseController
      before_action :set_batch, only: %i[show retry]

      def index
        batches = policy_scope(BatchArcaProcess).not_all_invoices_failed
        result  = pagination_result(batches.order(created_at: :desc))
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

        result = BatchArca::RetryService.new(batch: @batch).call

        if result[:success]
          render json: result[:batch], serializer: BatchArcaProcessSerializer, status: :ok
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
    end
  end
end
