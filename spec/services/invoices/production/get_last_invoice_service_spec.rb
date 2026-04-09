require 'rails_helper'

RSpec.describe Invoices::Production::GetLastInvoiceService, type: :service do
  let(:legal_number) { '20-12345678-9' }
  let(:sell_point_number) { '1' }
  let(:afip_code) { '11' }

  let(:afip_url) { 'https://servicios1.afip.gov.ar/wsfev1/service.asmx' }

  let(:token) { 'TOKEN_PROD_ABC' }
  let(:sign) { 'SIGN_PROD_XYZ' }

  before do
    allow(Invoices::Production::AuthWithArcaService)
      .to receive_message_chain(:new, :call)
      .and_return([token, sign])
  end

  subject(:service) do
    described_class.new(
      sell_point_number: sell_point_number,
      afip_code: afip_code,
      legal_number: legal_number
    )
  end

  def last_invoice_response_xml(cbte_nro: 42)
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

  def error_response_xml(error_msg: 'Punto de venta no habilitado')
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <FECompUltimoAutorizadoResponse xmlns="http://ar.gov.afip.dif.FEV1/">
            <FECompUltimoAutorizadoResult>
              <Errors>
                <Err>
                  <Code>10016</Code>
                  <Msg>#{error_msg}</Msg>
                </Err>
              </Errors>
            </FECompUltimoAutorizadoResult>
          </FECompUltimoAutorizadoResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  describe '#call' do
    context 'when AFIP returns the last invoice number' do
      before do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: last_invoice_response_xml(cbte_nro: 42),
                     headers: { 'Content-Type' => 'text/xml' })
      end

      it 'returns the last invoice number as an integer' do
        result = service.call
        expect(result).to eq(42)
      end

      it 'makes a POST request to the production AFIP endpoint' do
        service.call
        expect(WebMock).to have_requested(:post, afip_url)
          .with(headers: { 'SOAPAction' => 'http://ar.gov.afip.dif.FEV1/FECompUltimoAutorizado' })
      end

      it 'returns 0 when no invoices have been issued (CbteNro is 0)' do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: last_invoice_response_xml(cbte_nro: 0),
                     headers: { 'Content-Type' => 'text/xml' })
        result = service.call
        expect(result).to eq(0)
      end
    end

    context 'when AFIP returns an error' do
      let(:error_message) { 'Punto de venta no habilitado' }

      before do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: error_response_xml(error_msg: error_message),
                     headers: { 'Content-Type' => 'text/xml' })
      end

      it 'raises a RuntimeError with the AFIP error message' do
        expect { service.call }.to raise_error(RuntimeError, error_message)
      end
    end

    context 'when a network error occurs' do
      before do
        stub_request(:post, afip_url)
          .to_raise(Faraday::ConnectionFailed.new('timeout'))
      end

      it 'raises a Faraday::ConnectionFailed error' do
        expect { service.call }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end
end
