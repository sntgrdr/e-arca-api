require "open3"
require "tempfile"

module Invoices
  module Production
    class AuthWithArcaService
      URL = "https://wsaa.afip.gov.ar/ws/services/LoginCms".freeze
      CERTS_DIR = Rails.root.join("credentials/arca_certs")
      LEGAL_NUMBER_FORMAT = /\A\d{2}-\d{8}-\d\z/

      def initialize(legal_number:)
        @legal_number = legal_number
        validate_legal_number!
      end

      def call
        @user = User.find_by!(legal_number: @legal_number)

        return read_cached_ta if cached_ta_valid?

        create_login_ticket
        sign_ticket
        token, sign, expires_at = send_to_arca

        save_ta(token, sign, expires_at)
        [ token, sign ]
      end

      private

      def validate_legal_number!
        return if @legal_number.match?(LEGAL_NUMBER_FORMAT)

        raise ArgumentError, "Invalid legal_number format: #{@legal_number}. Expected format: XX-XXXXXXXX-X"
      end

      def cert_path
        path = CERTS_DIR.join("#{@legal_number}-certificate.crt")
        raise "Certificate not found for #{@legal_number} at #{path}" unless File.exist?(path)

        path
      end

      def key_path
        path = CERTS_DIR.join("#{@legal_number}-private_key.pem")
        raise "Private key not found for #{@legal_number} at #{path}" unless File.exist?(path)

        path
      end

      def create_login_ticket
        xml = Invoices::Production::GenerateLoginTicketService.generate("wsfe")
        @xml_tempfile = Tempfile.new([ "login_ticket_production", ".xml" ])
        @xml_tempfile.write(xml)
        @xml_tempfile.close
      end

      def sign_ticket
        cms_tempfile = Tempfile.new([ "login_ticket_production", ".xml.cms" ])
        cms_tempfile.close

        _stdout, stderr, status = Open3.capture3(
          "openssl", "cms",
          "-sign",
          "-in",      @xml_tempfile.path,
          "-out",     cms_tempfile.path,
          "-signer",  cert_path.to_s,
          "-inkey",   key_path.to_s,
          "-nodetach",
          "-outform", "PEM"
        )

        raise "Error al firmar ticket: #{stderr}" unless status.success?

        cms = File.read(cms_tempfile.path)
        @clean_cms = cms.gsub("-----BEGIN CMS-----", "")
                        .gsub("-----END CMS-----", "")
                        .strip
      ensure
        cms_tempfile&.unlink
        @xml_tempfile&.unlink
      end

      def send_to_arca
        # AFIP SSL: Using OpenSSL defaults (TLS 1.2+, modern ciphers).
        # If AFIP handshake fails, try: ssl: { verify: true, ciphers: 'DEFAULT:@SECLEVEL=1' }
        conn = Faraday.new(url: URL, ssl: { verify: true }) do |f|
          f.options.timeout      = 20
          f.options.open_timeout = 5
          f.adapter :net_http
        end

        response = conn.post do |req|
          req.headers["Content-Type"] = "text/xml;charset=UTF-8"
          req.headers["SOAPAction"]   = "urn:loginCms"
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
        @user.arca_token.present? &&
          @user.arca_token_expires_at.present? &&
          @user.arca_token_expires_at > Time.zone.now + 5.minutes
      end

      def read_cached_ta
        [ @user.arca_token, @user.arca_sign ]
      end

      def save_ta(token, sign, expires_at)
        @user.update!(
          arca_token: token,
          arca_sign: sign,
          arca_token_expires_at: Time.zone.parse(expires_at)
        )
      end
    end
  end
end
