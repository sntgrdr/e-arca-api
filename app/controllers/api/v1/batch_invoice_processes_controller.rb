module Api
  module V1
    class BatchInvoiceProcessesController < BaseController
      before_action :set_batch_process, only: %i[generate_pdfs download_pdfs]

      def index
        processes = policy_scope(BatchInvoiceProcess)
          .includes(:item, :sell_point, :batch_items)
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
        authorize BatchInvoiceProcess

        item_ids   = Array(params.dig(:batch_invoice_process, :item_ids)).map(&:to_i).uniq
        client_ids = Array(params.dig(:batch_invoice_process, :client_ids)).map(&:to_i).uniq

        errors = validate_selection(item_ids, client_ids)
        return render_errors(errors) if errors.any?

        build_params = batch_process_params.merge(user_id: current_user.id)
        build_params[:item_id] = item_ids.first if item_ids.any? && build_params[:item_id].blank?
        batch = BatchInvoiceProcess.new(build_params)

        ActiveRecord::Base.transaction do
          batch.save!
          attach_items(batch, item_ids)
          attach_clients(batch, client_ids)
        end

        BulkInvoiceCreationJob.perform_later(batch.id)
        render json: batch, serializer: BatchInvoiceProcessSerializer, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_errors(e.record.errors.full_messages)
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

      def validate_selection(item_ids, client_ids)
        errors = []

        if item_ids.any?
          if item_ids.size > BatchInvoiceProcess::MAX_ITEMS
            errors << I18n.t("batch_invoice_processes.errors.too_many_items",
                             max: BatchInvoiceProcess::MAX_ITEMS)
          else
            owned = Item.where(user_id: current_user.id, id: item_ids).count
            errors << I18n.t("batch_invoice_processes.errors.invalid_items") if owned != item_ids.size
          end
        end

        if client_ids.any?
          if client_ids.size > BatchInvoiceProcess::MAX_CLIENTS
            errors << I18n.t("batch_invoice_processes.errors.too_many_clients",
                             max: BatchInvoiceProcess::MAX_CLIENTS)
          else
            group_id = params.dig(:batch_invoice_process, :client_group_id)
            scope = if group_id.present?
              Client.where(user_id: current_user.id, id: client_ids, client_group_id: group_id)
            else
              Client.where(user_id: current_user.id, id: client_ids)
            end

            if scope.count != client_ids.size
              errors << I18n.t("batch_invoice_processes.errors.invalid_clients")
            end
          end
        else
          group_id = params.dig(:batch_invoice_process, :client_group_id)
          resolved_count = if group_id.present?
            ClientGroup.where(user_id: current_user.id, id: group_id)
                       .first&.clients&.where(active: true)&.count.to_i
          else
            Client.all_my_clients(current_user.id).count
          end

          if resolved_count > BatchInvoiceProcess::MAX_CLIENTS
            errors << I18n.t("batch_invoice_processes.errors.too_many_resolved_clients",
                             count: resolved_count, max: BatchInvoiceProcess::MAX_CLIENTS)
          end
        end

        errors
      end

      def attach_items(batch, item_ids)
        return if item_ids.empty?

        item_ids.each_with_index do |item_id, position|
          BatchInvoiceProcessItem.create!(
            batch_invoice_process: batch,
            item_id: item_id,
            position: position
          )
        end
      end

      def attach_clients(batch, client_ids)
        return if client_ids.empty?

        client_ids.each do |client_id|
          BatchInvoiceProcessClient.create!(
            batch_invoice_process: batch,
            client_id: client_id
          )
        end
      end
    end
  end
end
