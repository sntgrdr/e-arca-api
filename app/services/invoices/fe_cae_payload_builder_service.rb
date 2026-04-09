require "erb"

module Invoices
  class FeCaePayloadBuilderService
    def initialize(invoice:, token:, sign:)
      @invoice = invoice
      @token   = token
      @sign    = sign
    end

    def call
      template = if Rails.env.production?
                   Constants::ArcaIntegration::Production::FeCaeSolicitar::TEMPLATE
      else
                   Constants::ArcaIntegration::Development::FeCaeSolicitar::TEMPLATE
      end
      ERB.new(template).result(binding)
    end

    private

    attr_reader :invoice, :token, :sign

    def legal_number = invoice.user.legal_number
    def register = 1
    def sell_point = invoice.sell_point.number
    def afip_code = invoice.afip_code
    def document_type = invoice.document_type
    def document_number = invoice.document_number
    def number_from = invoice.number_from
    def number_to = invoice.number_to
    def date = invoice.date_to_s

    def invoice_total = format("%.2f", invoice.invoice_total)
    def non_tax_total = "0.00"
    def invoice_net_total = format("%.2f", invoice.invoice_net_total)
    def invoice_exempt_total = format("%.2f", invoice.invoice_exempt_total)
    def invoice_tribute_total = format("%.2f", invoice.invoice_tribute_total)
    def invoice_iva_total = format("%.2f", invoice.invoice_iva_total)

    def service_date_from = invoice.service_date_from
    def service_date_to = invoice.service_date_to
    def invoice_due_date = invoice.invoice_due_date

    def money = "PES"
    def money_value = "1.00"
    def client_tax_condition = invoice.client_tax_condition

    def iva_items = invoice.iva_items

    def has_associated_cbte?
      invoice.has_associated_cbte?
    end

    def associated_cbte_tipo
      invoice.associated_cbte_tipo if has_associated_cbte?
    end

    def associated_cbte_punto_vta
      invoice.associated_cbte_punto_vta if has_associated_cbte?
    end

    def associated_cbte_numero
      invoice.associated_cbte_numero if has_associated_cbte?
    end
  end
end
