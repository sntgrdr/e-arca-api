module Api
  module V1
    class ClientInvoicesController < BaseController
      before_action :set_invoice, only: %i[show update destroy send_to_arca download_pdf]

      def index
        base_scope = ClientInvoice.all_my_invoices(current_user.id).order(created_at: :desc)
        filtered = ::Filters::ClientInvoicesFilterService.new(params, base_scope).call
        result = paginate(filtered)
        render json: result[:data], meta: result[:pagination], each_serializer: ClientInvoiceSerializer
      end

      def show
        render json: @client_invoice, serializer: ClientInvoiceSerializer
      end

      def next_number
        render json: { number: ClientInvoice.current_number(current_user.id, params[:sell_point_id]) }
      end

      def create
        invoice = ClientInvoice.new(client_invoice_params.merge(user_id: current_user.id))

        if invoice.save
          render json: invoice, serializer: ClientInvoiceSerializer, status: :created
        else
          render_errors(invoice.errors.full_messages)
        end
      end

      def update
        if @client_invoice.update(client_invoice_params)
          render json: @client_invoice, serializer: ClientInvoiceSerializer
        else
          render_errors(@client_invoice.errors.full_messages)
        end
      end

      def destroy
        @client_invoice.destroy!
        head :no_content
      end

      def send_to_arca
        if @client_invoice.cae.present?
          return render json: { errors: ['La factura ya fue enviada a ARCA.'] }, status: :unprocessable_entity
        end

        result = "Invoices::#{Rails.env.camelize}::SendToArcaService".constantize.new(invoice: @client_invoice).call

        if result[:success]
          render json: @client_invoice.reload, serializer: ClientInvoiceSerializer
        else
          render json: { errors: Array(result[:errors]) }, status: :unprocessable_entity
        end
      end

      def download_pdf
        if @client_invoice.cae.blank?
          return render json: { errors: ['La factura no tiene CAE. No se puede generar el PDF.'] }, status: :unprocessable_entity
        end

        pdf = Invoices::PdfGeneratorService.new(invoice: @client_invoice).call
        filename = "factura_#{@client_invoice.invoice_type}_#{@client_invoice.number}.pdf"

        send_data pdf, filename: filename, type: 'application/pdf', disposition: 'inline'
      end

      private

      def set_invoice
        @client_invoice = ClientInvoice.where(user_id: current_user.id).find(params[:id])
      end

      def client_invoice_params
        params.require(:client_invoice).permit(
          :number, :date, :details, :invoice_type, :total_price,
          :sell_point_id, :client_id, :period,
          lines_attributes: [
            :id, :item_id, :description, :quantity,
            :unit_price, :final_price, :user_id, :iva_id, :_destroy
          ]
        )
      end
    end
  end
end
