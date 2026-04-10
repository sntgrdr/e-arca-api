require 'rails_helper'
require 'open3'

RSpec.describe Invoices::Production::AuthWithArcaService, type: :service do
  let(:legal_number) { '20-12345678-9' }
  let(:user) { create(:user, legal_number: legal_number, arca_token: nil, arca_sign: nil, arca_token_expires_at: nil) }

  let(:wsaa_url) { 'https://wsaa.afip.gov.ar/ws/services/LoginCms' }
  let(:token) { 'PD94bWwgdmVyc2lvbj0iMS4wIj9TOKEN' }
  let(:sign) { 'UEQ5NFdYd2dkbVZ5YzJsdmJqMGlNUzR3SWo5U0lHTg==' }
  let(:expires_at) { (Time.now + 12.hours).iso8601 }

  let(:certs_dir) { Rails.root.join('credentials/arca_certs') }
  let(:cert_path) { certs_dir.join("#{legal_number}-certificate.crt") }
  let(:key_path) { certs_dir.join("#{legal_number}-private_key.pem") }

  let(:fake_cms) { 'FAKECMSBASE64CONTENT==' }

  def wsaa_response_xml(token:, sign:, expires_at:)
    ta_xml = <<~TA
      <?xml version="1.0" encoding="UTF-8"?>
      <loginTicketResponse version="1.0">
        <header>
          <source>CN=wsaa, O=AFIP, C=AR</source>
          <destination>SERIALNUMBER=CUIT 20123456789, CN=Test</destination>
          <uniqueId>1234567890</uniqueId>
          <generationTime>#{(Time.now - 1.hour).iso8601}</generationTime>
          <expirationTime>#{expires_at}</expirationTime>
        </header>
        <credentials>
          <token>#{token}</token>
          <sign>#{sign}</sign>
        </credentials>
      </loginTicketResponse>
    TA

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <loginCmsResponse xmlns="http://wsaa.view.sua.dvadac.desein.afip.gov">
            <loginCmsReturn>#{CGI.escapeHTML(ta_xml)}</loginCmsReturn>
          </loginCmsResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  before do
    # Ensure the user record exists
    user

    # Stub file existence checks for certificates — service passes Pathname objects
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(cert_path.to_s).and_return(true)
    allow(File).to receive(:exist?).with(cert_path).and_return(true)
    allow(File).to receive(:exist?).with(key_path.to_s).and_return(true)
    allow(File).to receive(:exist?).with(key_path).and_return(true)

    # Stub GenerateLoginTicketService so we don't need real ticket XML
    allow(Invoices::Production::GenerateLoginTicketService)
      .to receive(:generate)
      .with('wsfe')
      .and_return('<loginTicketRequest />')

    # Stub the openssl CMS signing command
    mock_status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).and_return([ '', '', mock_status ])

    # After sign_ticket runs, stub the CMS file read
    allow(File).to receive(:read).and_call_original
  end

  subject(:service) { described_class.new(legal_number: legal_number) }

  describe '#call' do
    context 'when no valid cached token exists' do
      before do
        # The CMS file read after openssl signing
        allow(Open3).to receive(:capture3) do |*_args|
          mock_status = instance_double(Process::Status, success?: true)
          # Write the fake CMS to the tempfile path that gets created
          [ '', '', mock_status ]
        end

        allow_any_instance_of(Tempfile).to receive(:path).and_call_original
        allow(File).to receive(:read) do |path|
          if path.to_s.include?('login_ticket_production') && path.to_s.end_with?('.xml.cms')
            "-----BEGIN CMS-----\n#{fake_cms}\n-----END CMS-----"
          else
            File.method(:read).unbind.bind_call(File, path)
          end
        end

        stub_request(:post, wsaa_url)
          .to_return(
            status: 200,
            body: wsaa_response_xml(token: token, sign: sign, expires_at: expires_at),
            headers: { 'Content-Type' => 'text/xml' }
          )
      end

      it 'returns [token, sign]' do
        result = service.call
        expect(result).to eq([ token, sign ])
      end

      it 'saves the token and sign to the user record' do
        service.call
        user.reload
        expect(user.arca_token).to eq(token)
        expect(user.arca_sign).to eq(sign)
      end

      it 'sets arca_token_expires_at on the user' do
        service.call
        expect(user.reload.arca_token_expires_at).not_to be_nil
      end

      it 'makes a POST request to the WSAA endpoint' do
        service.call
        expect(WebMock).to have_requested(:post, wsaa_url)
          .with(headers: { 'SOAPAction' => 'urn:loginCms' })
      end
    end

    context 'when a valid cached token exists' do
      let(:cached_token) { 'cached_token_abc' }
      let(:cached_sign) { 'cached_sign_xyz' }

      before do
        user.update!(
          arca_token: cached_token,
          arca_sign: cached_sign,
          arca_token_expires_at: 2.hours.from_now
        )
      end

      it 'returns the cached [token, sign] without calling AFIP' do
        result = service.call
        expect(result).to eq([ cached_token, cached_sign ])
      end

      it 'does not make any HTTP request to WSAA' do
        service.call
        expect(WebMock).not_to have_requested(:post, wsaa_url)
      end

      it 'does not run the openssl signing command' do
        service.call
        expect(Open3).not_to have_received(:capture3)
      end
    end

    context 'when the cached token is expired' do
      before do
        user.update!(
          arca_token: 'old_token',
          arca_sign: 'old_sign',
          arca_token_expires_at: 3.minutes.from_now # less than 5 min — considered expired by guard
        )

        allow(Open3).to receive(:capture3) do |*_args|
          mock_status = instance_double(Process::Status, success?: true)
          [ '', '', mock_status ]
        end

        allow(File).to receive(:read) do |path|
          if path.to_s.include?('login_ticket_production') && path.to_s.end_with?('.xml.cms')
            "-----BEGIN CMS-----\n#{fake_cms}\n-----END CMS-----"
          else
            File.method(:read).unbind.bind_call(File, path)
          end
        end

        stub_request(:post, wsaa_url)
          .to_return(
            status: 200,
            body: wsaa_response_xml(token: token, sign: sign, expires_at: expires_at),
            headers: { 'Content-Type' => 'text/xml' }
          )
      end

      it 'fetches a new token from WSAA' do
        service.call
        expect(WebMock).to have_requested(:post, wsaa_url)
      end

      it 'returns the new token and sign' do
        result = service.call
        expect(result).to eq([ token, sign ])
      end
    end

    context 'when the legal_number format is invalid' do
      it 'raises an ArgumentError' do
        expect {
          described_class.new(legal_number: '12345678')
        }.to raise_error(ArgumentError, /Invalid legal_number format/)
      end
    end

    context 'when the openssl signing command fails' do
      before do
        user

        failed_status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return([ '', 'openssl error: certificate expired', failed_status ])

        allow(File).to receive(:read) do |path|
          if path.to_s.end_with?('.xml.cms')
            "-----BEGIN CMS-----\n#{fake_cms}\n-----END CMS-----"
          else
            File.method(:read).unbind.bind_call(File, path)
          end
        end
      end

      it 'raises a RuntimeError with signing error details' do
        expect { service.call }.to raise_error(RuntimeError, /Error al firmar ticket/)
      end
    end

    context 'when the WSAA returns an invalid response' do
      before do
        allow(Open3).to receive(:capture3) do |*_args|
          mock_status = instance_double(Process::Status, success?: true)
          [ '', '', mock_status ]
        end

        allow(File).to receive(:read) do |path|
          if path.to_s.end_with?('.xml.cms')
            "-----BEGIN CMS-----\n#{fake_cms}\n-----END CMS-----"
          else
            File.method(:read).unbind.bind_call(File, path)
          end
        end

        stub_request(:post, wsaa_url)
          .to_return(
            status: 200,
            body: '<soap:Envelope><soap:Body></soap:Body></soap:Envelope>',
            headers: { 'Content-Type' => 'text/xml' }
          )
      end

      it 'raises a RuntimeError about invalid WSAA response' do
        expect { service.call }.to raise_error(RuntimeError, /Respuesta WSAA inválida/)
      end
    end
  end
end
