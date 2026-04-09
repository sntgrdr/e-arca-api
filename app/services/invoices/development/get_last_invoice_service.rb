module Invoices
  module Development
    class GetLastInvoiceService
      URL = 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx'
      attr_reader :sell_point_number, :afip_code, :legal_number

      def initialize(sell_point_number:, afip_code:, legal_number:)
        @sell_point_number = sell_point_number
        @afip_code = afip_code
        @legal_number = legal_number
      end

      def call
        token, sign = Invoices::Development::AuthWithArcaService.new.call

        xml = build_xml(token, sign)

        response = send_request(xml)

        parse_response(response.body)
      end

      private

      def build_xml(token, sign)
        ERB.new(Constants::FeCompUltimoAutorizado::TEMPLATE).result(binding)
      end

      def send_request(xml)
        Faraday.post(URL) do |req|
          req.headers['Content-Type'] = 'text/xml; charset=utf-8'
          req.headers['SOAPAction'] =
            'http://ar.gov.afip.dif.FEV1/FECompUltimoAutorizado'
          req.body = xml
        end
      end


      def parse_response(body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        doc.at_xpath('//CbteNro')&.content&.to_i
      end
    end
  end
end
