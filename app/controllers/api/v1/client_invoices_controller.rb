module Api
  module V1
    class ClientInvoicesController < BaseController
      before_action :set_invoice, only: %i[show update destroy send_to_arca download_pdf history]

      def index
        base_scope = policy_scope(ClientInvoice)
          .includes(:sell_point, :credit_notes, client: [ :client_group, :iva ], lines: :iva)
          .order(created_at: :desc)
        filtered = ::Filters::ClientInvoicesFilterService.new(params, base_scope).call
        result = paginate(filtered)
        render json: result[:data], meta: result[:pagination], each_serializer: ClientInvoiceSerializer
      end

      def show
        authorize @client_invoice
        render json: @client_invoice, serializer: ClientInvoiceDetailSerializer
      end

      def next_number
        authorize ClientInvoice
        render json: { number: ClientInvoice.current_number(current_user.id, params[:sell_point_id], params[:invoice_type]) }
      end

      def create
        invoice = ClientInvoice.new(client_invoice_params.merge(user_id: current_user.id))
        invoice.lines.each { |line| line.user_id = current_user.id }
        authorize invoice

        if invoice.save
          render json: invoice, serializer: ClientInvoiceSerializer, status: :created
        else
          render_errors(invoice.errors.full_messages)
        end
      end

      def update
        authorize @client_invoice

        if @client_invoice.afip_authorized?
          return render json: {
            error: { code: "cannot_edit", message: I18n.t("client_invoices.errors.cannot_edit_authorized") }
          }, status: :unprocessable_entity
        end

        @client_invoice.assign_attributes(client_invoice_params)
        @client_invoice.lines.each { |line| line.user_id = current_user.id if line.user_id.blank? }

        if @client_invoice.save
          render json: @client_invoice.reload, serializer: ClientInvoiceSerializer
        else
          render_errors(@client_invoice.errors.full_messages)
        end
      end

      def destroy
        authorize @client_invoice

        if @client_invoice.afip_authorized?
          return render json: {
            error: { code: "cannot_delete", message: "Cannot delete an AFIP-authorized invoice. Issue a credit note instead." }
          }, status: :unprocessable_entity
        end

        @client_invoice.destroy!
        head :no_content
      end

      def send_to_arca
        authorize @client_invoice

        if @client_invoice.authorized?
          return render json: @client_invoice, serializer: ClientInvoiceSerializer
        end

        unless @client_invoice.submittable?
          return render json: {
            error: { code: "conflict", message: "Invoice is currently being processed" }
          }, status: :conflict
        end

        result = arca_service_module::SendToArcaService.new(invoice: @client_invoice).call

        if result[:success]
          render json: @client_invoice.reload, serializer: ClientInvoiceSerializer
        else
          render json: { errors: Array(result[:errors]) }, status: :unprocessable_entity
        end
      end

      def history
        authorize @client_invoice
        versions = @client_invoice.versions.order(created_at: :desc).map do |v|
          {
            id: v.id,
            event: v.event,
            who: v.whodunnit,
            when: v.created_at,
            changes: v.object_changes ? YAML.safe_load(v.object_changes, permitted_classes: [ BigDecimal, Date, Time, ActiveSupport::TimeWithZone ]) : {}
          }
        end
        render json: { history: versions }
      end

      def download_pdf
        authorize @client_invoice

        if @client_invoice.cae.blank?
          return render json: { errors: [ "La factura no tiene CAE. No se puede generar el PDF." ] }, status: :unprocessable_entity
        end

        pdf = Invoices::PdfGeneratorService.new(invoice: @client_invoice).call
        filename = "factura_#{@client_invoice.invoice_type}_#{@client_invoice.number}.pdf"

        send_data pdf, filename: filename, type: "application/pdf", disposition: "inline"
      end

      private

      def set_invoice
        @client_invoice = ClientInvoice
          .kept
          .includes(:client, :sell_point, :credit_notes, lines: :iva)
          .where(user_id: current_user.id)
          .find(params[:id])
      end

      def client_invoice_params
        params.require(:client_invoice).permit(
          :number, :date, :details, :invoice_type, :total_price,
          :sell_point_id, :client_id, :period,
          lines_attributes: [
            :id, :item_id, :description, :quantity,
            :unit_price, :final_price, :iva_id, :_destroy
          ]
        )
      end
    end
  end
end
