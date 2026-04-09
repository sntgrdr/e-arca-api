require 'rails_helper'
require 'open3'
require 'tmpdir'

RSpec.describe Invoices::Development::AuthWithArcaService, type: :service do
  let(:wsaa_url) { 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms' }
  let(:token) { 'dev_token_HOMOLOGACION_abc123' }
  let(:sign) { 'dev_sign_HOMOLOGACION_xyz789' }
  let(:expires_at) { (Time.now + 12.hours).iso8601 }

  let(:ta_path) { Rails.root.join('tmp/arca_wsfe_ta.json') }
  let(:fake_cms) { 'DEVFAKECMSBASE64==' }

  def wsaa_response_xml(token:, sign:, expires_at:)
    ta_xml = <<~TA
      <?xml version="1.0" encoding="UTF-8"?>
      <loginTicketResponse version="1.0">
        <header>
          <source>CN=wsaahomo, O=AFIP, C=AR</source>
          <destination>SERIALNUMBER=CUIT TEST, CN=Test Dev</destination>
          <uniqueId>9876543210</uniqueId>
          <generationTime>#{(Time.now - 30.minutes).iso8601}</generationTime>
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
    # Stub the login ticket generation
    allow(Invoices::Development::GenerateLoginTicketService)
      .to receive(:generate)
      .with('wsfe')
      .and_return('<loginTicketRequest />')

    # Stub File.write so we don't write temp files during tests
    allow(File).to receive(:write).and_call_original
    allow(File).to receive(:write)
      .with(Rails.root.join('tmp', 'LoginTicketRequest.xml').to_s, anything)

    # Stub the openssl CMS signing command — success by default
    mock_status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).and_return(['', '', mock_status])

    # Stub reading the CMS output file — service passes a Pathname, so stub both string and Pathname forms
    cms_path_str = Rails.root.join('tmp', 'LoginTicketRequest.xml.cms').to_s
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(cms_path_str)
      .and_return("-----BEGIN CMS-----\n#{fake_cms}\n-----END CMS-----")
    allow(File).to receive(:read).with(Rails.root.join('tmp', 'LoginTicketRequest.xml.cms'))
      .and_return("-----BEGIN CMS-----\n#{fake_cms}\n-----END CMS-----")

    # Remove any leftover TA cache file before each test
    File.delete(ta_path) if File.exist?(ta_path)
  end

  after do
    # Use the real File.exist? check (not stubs) to avoid deleting non-existent files
    File.delete(ta_path.to_s) if File.method(:exist?).unbind.bind_call(File, ta_path.to_s)
  rescue Errno::ENOENT
    # File was never written or already deleted — nothing to clean up
  end

  subject(:service) { described_class.new }

  describe '#call' do
    context 'when no cached TA file exists' do
      before do
        stub_request(:post, wsaa_url)
          .to_return(
            status: 200,
            body: wsaa_response_xml(token: token, sign: sign, expires_at: expires_at),
            headers: { 'Content-Type' => 'text/xml' }
          )
      end

      it 'returns [token, sign]' do
        result = service.call
        expect(result).to eq([token, sign])
      end

      it 'makes a POST request to the homologation WSAA endpoint' do
        service.call
        expect(WebMock).to have_requested(:post, wsaa_url)
          .with(headers: { 'SOAPAction' => 'urn:loginCms' })
      end

      it 'writes the TA data to the cache file' do
        # TA_PATH is a Pathname constant, so File.write receives a Pathname argument
        expect(File).to receive(:write).with(ta_path, anything)
        service.call
      end
    end

    context 'when a valid TA cache file exists' do
      let(:cached_token) { 'cached_dev_token' }
      let(:cached_sign) { 'cached_dev_sign' }

      before do
        ta_data = {
          token: cached_token,
          sign: cached_sign,
          expires_at: 3.hours.from_now.iso8601
        }.to_json

        # TA_PATH is a Pathname constant; stub both Pathname and String forms
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(ta_path).and_return(true)
        allow(File).to receive(:exist?).with(ta_path.to_s).and_return(true)
        allow(File).to receive(:read).with(ta_path).and_return(ta_data)
        allow(File).to receive(:read).with(ta_path.to_s).and_return(ta_data)
      end

      it 'returns the cached [token, sign] without calling WSAA' do
        result = service.call
        expect(result).to eq([cached_token, cached_sign])
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

    context 'when the TA cache file is expired (within 5 minute buffer)' do
      before do
        ta_data = {
          token: 'old_dev_token',
          sign: 'old_dev_sign',
          expires_at: 4.minutes.from_now.iso8601
        }.to_json

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(ta_path).and_return(true)
        allow(File).to receive(:exist?).with(ta_path.to_s).and_return(true)
        allow(File).to receive(:read).with(ta_path).and_return(ta_data)
        allow(File).to receive(:read).with(ta_path.to_s).and_return(ta_data)

        stub_request(:post, wsaa_url)
          .to_return(
            status: 200,
            body: wsaa_response_xml(token: token, sign: sign, expires_at: expires_at),
            headers: { 'Content-Type' => 'text/xml' }
          )
      end

      it 'fetches a fresh token from WSAA' do
        service.call
        expect(WebMock).to have_requested(:post, wsaa_url)
      end

      it 'returns the new [token, sign]' do
        result = service.call
        expect(result).to eq([token, sign])
      end
    end

    context 'when the TA cache file is corrupt/unparseable' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(ta_path).and_return(true)
        allow(File).to receive(:exist?).with(ta_path.to_s).and_return(true)
        allow(File).to receive(:read).with(ta_path).and_return('{ not valid json !!!}')
        allow(File).to receive(:read).with(ta_path.to_s).and_return('{ not valid json !!!}')

        stub_request(:post, wsaa_url)
          .to_return(
            status: 200,
            body: wsaa_response_xml(token: token, sign: sign, expires_at: expires_at),
            headers: { 'Content-Type' => 'text/xml' }
          )
      end

      it 'treats the cache as invalid and fetches a new token' do
        result = service.call
        expect(result).to eq([token, sign])
      end
    end

    context 'when the openssl signing command fails' do
      before do
        failed_status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(['', 'no such file', failed_status])
      end

      it 'raises a RuntimeError' do
        expect { service.call }.to raise_error(RuntimeError)
      end
    end

    context 'when WSAA returns an invalid response' do
      before do
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
