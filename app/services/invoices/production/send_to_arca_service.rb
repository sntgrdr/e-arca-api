module Invoices
  module Production
    class SendToArcaService
      URL = "https://servicios1.afip.gov.ar/wsfev1/service.asmx".freeze

      attr_reader :invoice

      def initialize(invoice:)
        @invoice = invoice
      end

      def call
        return { success: true, invoice: @invoice } if @invoice.authorized?

        @invoice.with_lock do
          return { success: false, errors: "Invoice is being processed" } if @invoice.submitting?
          return { success: true, invoice: @invoice } if @invoice.authorized?
          @invoice.update!(afip_status: :submitting)
        end

        @token, @sign = Invoices::Production::AuthWithArcaService.new(
          legal_number: @invoice.user.legal_number
        ).call
        xml = soap_xml
        result = send_to_arca(xml)
        process_afip_response(result[:body])
      rescue StandardError => e
        @invoice.reload.update!(afip_status: :rejected) if @invoice.submitting?
        raise
      end

      private

      def soap_xml
        Invoices::FeCaePayloadBuilderService
          .new(invoice: @invoice, token: @token, sign: @sign)
          .call
      end

      def send_to_arca(xml)
        # AFIP SSL: Using OpenSSL defaults (TLS 1.2+, modern ciphers).
        # If AFIP handshake fails, try: ssl: { verify: true, ciphers: 'DEFAULT:@SECLEVEL=1' }
        conn = Faraday.new(url: URL, ssl: { verify: true }) do |f|
          f.options.timeout      = 20
          f.options.open_timeout = 5
          f.adapter :net_http
        end

        response = conn.post do |req|
          req.headers["Content-Type"] = "text/xml; charset=utf-8"
          req.headers["SOAPAction"]   = "http://ar.gov.afip.dif.FEV1/FECAESolicitar"
          req.body = xml
        end

        {
          http_status: response.status,
          body: response.body
        }
      end

      def process_afip_response(xml)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!

        cab = doc.at_xpath("//FeCabResp")
        det = doc.at_xpath("//FECAEDetResponse")

        raise I18n.t("services.afip.malformed_response", xml: xml.truncate(200)) if cab.nil? || det.nil?

        resultado = cab.at_xpath("Resultado")&.content
        cae       = det.at_xpath("CAE")&.content.presence

        if resultado == "A" && cae.present?
          persist_success!(doc, xml)
          { success: true, invoice: invoice }
        else
          error_msg = extract_afip_error(doc)
          persist_error!(xml, error_msg)
          { success: false, errors: error_msg }
        end
      end

      def persist_success!(doc, xml)
        cab = doc.at_xpath("//FeCabResp")
        det = doc.at_xpath("//FECAEDetResponse")

        invoice.update!(
          cae:                 det.at_xpath("CAE")&.content,
          cae_expiration:      Date.strptime(det.at_xpath("CAEFchVto").content, "%Y%m%d"),
          afip_invoice_number: det.at_xpath("CbteDesde")&.content,
          afip_result:         "A",
          afip_authorized_at:  Time.strptime(
            cab.at_xpath("FchProceso").content,
            "%Y%m%d%H%M%S"
          ),
          afip_response_xml: xml,
          afip_status: :authorized
        )
      end

      def extract_afip_error(doc)
        if (err = doc.at_xpath("//Errors/Err"))
          err.at_xpath("Msg")&.content
        elsif (obs = doc.at_xpath("//Observaciones/Obs"))
          obs.at_xpath("Msg")&.content
        else
          I18n.t("services.afip.unknown_error")
        end
      end

      def persist_error!(xml, error_msg)
        invoice.update!(
          afip_result:       "R",
          afip_response_xml: xml,
          afip_status: :rejected
        )
      end
    end
  end
end
