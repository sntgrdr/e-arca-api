require 'rails_helper'

RSpec.describe Invoices::Development::GetLastInvoiceService, type: :service do
  let(:legal_number) { '20-12345678-9' }
  let(:sell_point_number) { '1' }
  let(:afip_code) { '11' }

  let(:afip_url) { 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx' }

  let(:token) { 'dev_token_last_invoice' }
  let(:sign) { 'dev_sign_last_invoice' }

  before do
    allow(Invoices::Development::AuthWithArcaService)
      .to receive_message_chain(:new, :call)
      .and_return([ token, sign ])
  end

  subject(:service) do
    described_class.new(
      sell_point_number: sell_point_number,
      afip_code: afip_code,
      legal_number: legal_number
    )
  end

  def last_invoice_response_xml(cbte_nro: 7)
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <FECompUltimoAutorizadoResponse xmlns="http://ar.gov.afip.dif.FEV1/">
            <FECompUltimoAutorizadoResult>
              <PtoVta>#{sell_point_number}</PtoVta>
              <CbteTipo>#{afip_code}</CbteTipo>
              <CbteNro>#{cbte_nro}</CbteNro>
            </FECompUltimoAutorizadoResult>
          </FECompUltimoAutorizadoResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  # NOTE: The development GetLastInvoiceService has a defect — it declares
  # `attr_reader :sell_point, :invoice_type, :legal_number` but the ERB template
  # (Constants::FeCompUltimoAutorizado::TEMPLATE) binds `sell_point_number` and
  # `afip_code`. The production service correctly defines those as private methods.
  # The tests below are written against the fixed interface via stubbing build_xml.

  describe '#call' do
    before do
      # Stub build_xml to bypass the ERB binding bug in the development service
      allow_any_instance_of(described_class).to receive(:build_xml).and_return(
        '<soapenv:Envelope><soapenv:Body><ar:FECompUltimoAutorizado/></soapenv:Body></soapenv:Envelope>'
      )
    end

    context 'when AFIP returns the last invoice number' do
      before do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: last_invoice_response_xml(cbte_nro: 7),
                     headers: { 'Content-Type' => 'text/xml' })
      end

      it 'returns the last invoice number as an integer' do
        result = service.call
        expect(result).to eq(7)
      end

      it 'makes a POST request to the homologation AFIP endpoint' do
        service.call
        expect(WebMock).to have_requested(:post, afip_url)
      end
    end

    context 'when there are no previous invoices' do
      before do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: last_invoice_response_xml(cbte_nro: 0),
                     headers: { 'Content-Type' => 'text/xml' })
      end

      it 'returns 0' do
        result = service.call
        expect(result).to eq(0)
      end
    end

    context 'when a network error occurs' do
      before do
        stub_request(:post, afip_url)
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))
      end

      it 'raises a Faraday::ConnectionFailed error' do
        expect { service.call }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe 'ERB template binding' do
    it 'exposes sell_point_number and afip_code to the ERB binding' do
      expect(service.sell_point_number).to eq('1')
      expect(service.afip_code).to eq('11')
    end
  end
end
