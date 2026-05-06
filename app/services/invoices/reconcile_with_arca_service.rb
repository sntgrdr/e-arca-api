module Invoices
  class ReconcileWithArcaService
    def initialize(invoice:)
      @invoice = invoice
    end

    def call
      result = consult_service.call
      return { authorized: false } unless result[:authorized]

      persist_success(result)
      { authorized: true }
    end

    private

    def consult_service
      arca_module.const_get(:FeCompConsultService).new(
        invoice_number:    @invoice.number,
        sell_point_number: @invoice.sell_point.number,
        afip_code:         @invoice.afip_code,
        legal_number:      @invoice.user.legal_number
      )
    end

    def persist_success(data)
      @invoice.update!(
        cae:                 data[:cae],
        cae_expiration:      data[:cae_expiration],
        afip_authorized_at:  data[:afip_authorized_at],
        afip_invoice_number: data[:afip_invoice_number],
        afip_result:         "A",
        afip_status:         :authorized
      )
    end

    def arca_module
      Rails.env.production? ? Invoices::Production : Invoices::Development
    end
  end
end
