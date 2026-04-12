module Api
  module V1
    class BatchInvoiceProcessesController < BaseController
      before_action :set_batch_process, only: %i[generate_pdfs download_pdfs]

      def index
        processes = policy_scope(BatchInvoiceProcess)
          .includes(:item, :sell_point)
          .order(created_at: :desc)
        render json: processes, each_serializer: BatchInvoiceProcessSerializer
      end

      def show
        batch = BatchInvoiceProcess
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
        batch = BatchInvoiceProcess.new(batch_process_params.merge(user_id: current_user.id))
        authorize batch

        if batch.save
          BulkInvoiceCreationJob.perform_later(batch.id)
          render json: batch, serializer: BatchInvoiceProcessSerializer, status: :created
        else
          render_errors(batch.errors.full_messages)
        end
      end

      def generate_pdfs
        authorize @batch_process
        unless @batch_process.completed?
          return render json: { errors: [ "El proceso aún no ha finalizado." ] }, status: :unprocessable_entity
        end

        BatchPdfGenerationJob.perform_later(@batch_process.id)
        render json: { message: "Generación de PDFs iniciada." }
      end

      def download_pdfs
        authorize @batch_process
        unless @batch_process.pdf_generated? && @batch_process.pdf_zip.attached?
          return render json: { errors: [ "Los PDFs aún no están disponibles." ] }, status: :unprocessable_entity
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
          :client_group_id, :item_id, :sell_point_id, :date, :period
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
