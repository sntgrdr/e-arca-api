module Invoices
  module Production
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

        last_number = Invoices::Production::GetLastInvoiceService.new(
          sell_point_number: @sell_point_number,
          afip_code:         @afip_code,
          legal_number:      @user.legal_number
        ).call

        { success: true, last_number: last_number }
      end

      private

      def validate
        return 'Parámetros requeridos.'           if @sell_point_number.blank? || @afip_code.blank?
        return 'Punto de venta inválido.'         unless @sell_point_number.to_i.positive?
        return 'Tipo de comprobante inválido.'    unless VALID_AFIP_CODES.include?(@afip_code)
        return 'Punto de venta no encontrado.'    unless SellPoint.exists?(number: @sell_point_number, user_id: @user.id)

        nil
      end
    end
  end
end
