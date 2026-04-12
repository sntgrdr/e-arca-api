module Invoices
  module Development
    class LastInvoiceQueryService
      VALID_AFIP_CODES = %w[1 6 11 19].freeze

      def initialize(sell_point_number:, afip_code:, user:)
        @sell_point_number = sell_point_number
        @afip_code         = afip_code
        @user              = user
      end

      def call
        error = validate
        return { success: false, error: error } if error

        last_number = Invoices::Development::GetLastInvoiceService.new(
          sell_point_number: @sell_point_number,
          afip_code:         @afip_code,
          legal_number:      @user.legal_number
        ).call

        invoice = ClientInvoice
          .where(user_id: @user.id, number: last_number)
          .order(created_at: :desc)
          .first

        { success: true, last_number: last_number, afip_authorized_at: invoice&.afip_authorized_at&.iso8601 }
      end

      private

      def validate
        return "Parámetros requeridos."        if @sell_point_number.blank? || @afip_code.blank?
        return "Punto de venta inválido."      unless @sell_point_number.to_i.positive?
        return "Tipo de comprobante inválido." unless VALID_AFIP_CODES.include?(@afip_code)
        return "Punto de venta no encontrado." unless SellPoint.exists?(number: @sell_point_number, user_id: @user.id)

        nil
      end
    end
  end
end
