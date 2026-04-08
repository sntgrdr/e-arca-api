module Invoices
  module Production
    class GetLastInvoiceService
      URL = 'https://servicios1.afip.gov.ar/wsfev1/service.asmx'.freeze

      def initialize(sell_point_number:, afip_code:, legal_number:)
        @sell_point_number = sell_point_number
        @afip_code         = afip_code
        @legal_number      = legal_number
      end

      def call
        token, sign = Invoices::Production::AuthWithArcaService.new(
          legal_number: @legal_number
        ).call
        xml = build_xml(token, sign)
        response = send_request(xml)
        parse_response(response.body)
      end

      private

      def sell_point_number = @sell_point_number
      def afip_code         = @afip_code
      def legal_number      = @legal_number

      def build_xml(token, sign)
        ERB.new(Constants::FeCompUltimoAutorizado::TEMPLATE).result(binding)
      end

      def send_request(xml)
        conn = Faraday.new(url: URL, ssl: { verify: true, ciphers: 'DEFAULT:@SECLEVEL=0' }) do |f|
          f.adapter :net_http
        end

        conn.post do |req|
          req.headers['Content-Type'] = 'text/xml; charset=utf-8'
          req.headers['SOAPAction']   = 'http://ar.gov.afip.dif.FEV1/FECompUltimoAutorizado'
          req.body = xml
        end
      end

      def parse_response(body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        if (err = doc.at_xpath('//Errors/Err'))
          raise err.at_xpath('Msg')&.content || 'Error desconocido en respuesta AFIP'
        end

        doc.at_xpath('//CbteNro')&.content&.to_i
      end
    end
  end
end
