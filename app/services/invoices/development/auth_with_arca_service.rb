require "open3"

module Invoices
  module Development
    class AuthWithArcaService
      URL = "https://wsaahomo.afip.gov.ar/ws/services/LoginCms".freeze

      CERT_PATH = Rails.root.join("config/arca_certs/certificado.pem")
      KEY_PATH  = Rails.root.join("config/arca_certs/MiClavePrivada")
      TA_PATH = Rails.root.join("tmp/arca_wsfe_ta.json")

      def initialize; end

      def call
        return read_cached_ta if cached_ta_valid?

        create_login_ticket
        sign_ticket
        token, sign, expires_at = send_to_arca

        save_ta(token, sign, expires_at)
        [ token, sign ]
      end

      private

      def create_login_ticket
        xml = Invoices::Development::GenerateLoginTicketService.generate("wsfe")
        @xml_path = Rails.root.join("tmp", "LoginTicketRequest.xml")
        File.write(@xml_path, xml)
      end

      def sign_ticket
        cms_path = Rails.root.join("tmp", "LoginTicketRequest.xml.cms")

        stdout, stderr, status = Open3.capture3(
          "openssl", "cms",
          "-sign",
          "-in", @xml_path.to_s,
          "-out", cms_path.to_s,
          "-signer", CERT_PATH.to_s,
          "-inkey", KEY_PATH.to_s,
          "-nodetach",
          "-outform", "PEM"
        )

        unless status.success?
          raise "Error al firmar ticket: #{stderr}"
        end

        cms = File.read(cms_path)
        @clean_cms = cms.gsub("-----BEGIN CMS-----", "")
                        .gsub("-----END CMS-----", "")
                        .strip
      end

      def send_to_arca
        conn = Faraday.new(url: URL, ssl: { verify: true }) do |f|
          f.options.timeout      = 20
          f.options.open_timeout = 5
          f.adapter Faraday.default_adapter
        end

        response = conn.post do |req|
          req.headers["Content-Type"] = "text/xml;charset=UTF-8"
          req.headers["SOAPAction"] = "urn:loginCms"
          req.body = <<~XML
            <soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/'
                              xmlns:wsaa='http://wsaa.view.sua.dvadac.desein.afip.gov'>
              <soapenv:Header/>
              <soapenv:Body>
                <wsaa:loginCms>
                  <wsaa:in0>#{@clean_cms}</wsaa:in0>
                </wsaa:loginCms>
              </soapenv:Body>
            </soapenv:Envelope>
          XML
        end

        doc = Nokogiri::XML(response.body)
        doc.remove_namespaces!

        ta_xml = doc.at_xpath("//loginCmsReturn")&.content
        raise "Respuesta WSAA inválida" if ta_xml.blank?

        ta_doc = Nokogiri::XML(ta_xml)

        token      = ta_doc.at_xpath("//token")&.content
        sign       = ta_doc.at_xpath("//sign")&.content
        expires_at = ta_doc.at_xpath("//expirationTime")&.content

        raise "Token o Sign faltante en TA" if token.blank? || sign.blank?

        [ token, sign, expires_at ]
      end

      def cached_ta_valid?
        return false unless File.exist?(TA_PATH)

        data = JSON.parse(File.read(TA_PATH))
        Time.zone.parse(data["expires_at"]) > Time.zone.now + 5.minutes
      rescue StandardError => e
        Rails.logger.warn("[AuthWithArcaService] Failed to read cached TA: #{e.class}: #{e.message}")
        false
      end

      def read_cached_ta
        data = JSON.parse(File.read(TA_PATH))
        [ data["token"], data["sign"] ]
      end

      def save_ta(token, sign, expires_at)
        File.write(
          TA_PATH,
          {
            token: token,
            sign: sign,
            expires_at: expires_at
          }.to_json
        )
      end
    end
  end
end
