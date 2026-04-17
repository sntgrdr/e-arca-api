module Api
  module V1
    class BatchInvoiceProcessesController < BaseController
      before_action :set_batch_process, only: %i[generate_pdfs download_pdfs]

      def index
        scope = policy_scope(BatchInvoiceProcess)
          .includes(:item, :sell_point, :client_group, batch_invoice_process_items: :item)
          .order(created_at: :desc)
        scope = scope.where(process_type: params[:process_type]) if params[:process_type].present?
        result = paginate(scope)
        render_paginated(result, serializer: BatchInvoiceProcessSerializer)
      end

      def show
        batch = BatchInvoiceProcess
          .includes(:sell_point, :client_group, :item, batch_invoice_process_items: :item)
          .where(user_id: current_user.id)
          .find(params[:id])
        authorize batch
        response.headers["Cache-Control"] = "no-store"
        render json: batch, serializer: BatchInvoiceProcessDetailSerializer
      end

      def last_invoice_date
        authorize BatchInvoiceProcess
        last_invoice = ClientInvoice
          .where(user_id: current_user.id, sell_point_id: params[:sell_point_id])
          .where.not(cae: nil)
          .order(date: :desc)
          .first

        render json: { date: last_invoice&.date&.iso8601 }
      end

      def create
        authorize BatchInvoiceProcess

        process_type = params.dig(:batch_invoice_process, :process_type).presence || "per_client"
        item_ids     = Array(params.dig(:batch_invoice_process, :item_ids)).map(&:to_i).uniq

        result = if process_type == "final_consumer"
          BatchInvoiceProcessCreators::FinalConsumer.call(
            user:             current_user,
            permitted_params: batch_process_params,
            item_ids:         item_ids
          )
        else
          client_ids = Array(params.dig(:batch_invoice_process, :client_ids)).map(&:to_i).uniq
          BatchInvoiceProcessCreators::PerClient.call(
            user:             current_user,
            permitted_params: batch_process_params,
            item_ids:         item_ids,
            client_ids:       client_ids
          )
        end

        if result.success?
          render json: result.batch, serializer: BatchInvoiceProcessSerializer, status: :created
        else
          render_errors(result.errors)
        end
      end

      def generate_pdfs
        authorize @batch_process
        unless @batch_process.completed?
          return render json: { errors: [ I18n.t("batch_invoice_processes.errors.not_completed") ] }, status: :unprocessable_entity
        end

        BatchPdfGenerationJob.perform_later(@batch_process.id, current_user.id)
        render json: { message: I18n.t("batch_invoice_processes.messages.pdfs_generating") }
      end

      def download_pdfs
        authorize @batch_process
        unless @batch_process.pdf_generated? && @batch_process.pdf_zip.attached?
          return render json: { errors: [ I18n.t("batch_invoice_processes.errors.pdfs_not_available") ] }, status: :unprocessable_entity
        end

        send_data @batch_process.pdf_zip.download,
                  filename: @batch_process.pdf_zip.filename.to_s,
                  type: @batch_process.pdf_zip.content_type,
                  disposition: "attachment"
      end

      private

      def set_batch_process
        @batch_process = BatchInvoiceProcess.where(user_id: current_user.id).find(params[:id])
      end

      def batch_process_params
        permitted = params.require(:batch_invoice_process).permit(
          :client_group_id, :item_id, :sell_point_id, :date, :period,
          :invoice_type, :quantity
        )

        if permitted[:period].present? && permitted[:period].match?(%r{\A\d{2}/\d{4}\z})
          month, year = permitted[:period].split("/")
          permitted[:period] = Date.new(year.to_i, month.to_i, 1)
        end

        permitted
      end
    end
  end
end
