module Invoices
  module Production
    class FeCompConsultarService
      URL = "https://servicios1.afip.gov.ar/wsfev1/service.asmx".freeze

      def initialize(invoice_number:, sell_point_number:, afip_code:, legal_number:)
        @invoice_number    = invoice_number.to_s
        @sell_point_number = sell_point_number.to_s
        @afip_code         = afip_code.to_s
        @legal_number      = legal_number.to_s
      end

      def call
        @token, @sign = Invoices::Production::AuthWithArcaService.new(
          legal_number: @legal_number
        ).call

        xml      = build_xml
        response = send_request(xml)
        parse_response(response.body)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed
        raise
      rescue StandardError => e
        Rails.logger.error("[FeCompConsultarService] #{e.class}: #{e.message}")
        { authorized: false, cae: nil, error: e.message }
      end

      private

      attr_reader :invoice_number, :sell_point_number, :afip_code, :legal_number

      def token = @token
      def sign  = @sign

      def build_xml
        ERB.new(Constants::ArcaIntegration::Production::FeCompConsultar::TEMPLATE).result(binding)
      end

      def send_request(xml)
        conn = Faraday.new(url: URL) do |f|
          f.options.timeout      = 20
          f.options.open_timeout = 5
          f.adapter :net_http
        end

        conn.post do |req|
          req.headers["Content-Type"] = "text/xml; charset=utf-8"
          req.headers["SOAPAction"]   = "http://ar.gov.afip.dif.FEV1/FECompConsultar"
          req.body = xml
        end
      end

      def parse_response(body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        if (err = doc.at_xpath("//Errors/Err"))
          return { authorized: false, cae: nil, error: err.at_xpath("Msg")&.content }
        end

        result = doc.at_xpath("//ResultGet")
        return { authorized: false, cae: nil, error: "Empty response" } if result.nil?

        resultado = result.at_xpath("Resultado")&.content
        cae       = result.at_xpath("CAE")&.content.presence

        return { authorized: false, cae: nil } unless resultado == "A" && cae.present?

        {
          authorized:          true,
          cae:                 cae,
          cae_expiration:      Date.strptime(result.at_xpath("CAEFchVto").content, "%Y%m%d"),
          afip_authorized_at:  Time.zone.strptime(result.at_xpath("FchProceso").content, "%Y%m%d%H%M%S"),
          afip_invoice_number: result.at_xpath("CbteDesde")&.content
        }
      end
    end
  end
end
