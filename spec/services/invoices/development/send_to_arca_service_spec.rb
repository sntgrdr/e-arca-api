require 'rails_helper'

RSpec.describe Invoices::Development::SendToArcaService, type: :service do
  let(:user) { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:invoice) { create(:client_invoice, :with_lines, user: user, client: client, sell_point: sell_point) }

  let(:token) { 'dev_token_abc' }
  let(:sign) { 'dev_sign_xyz' }

  let(:afip_url) { 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx' }

  before do
    allow(Invoices::Development::AuthWithArcaService)
      .to receive_message_chain(:new, :call)
      .and_return([ token, sign ])
  end

  subject(:service) { described_class.new(invoice: invoice) }

  def approved_response_xml(cae: '75109284616809', invoice_number: '1')
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <FECAESolicitarResponse xmlns="http://ar.gov.afip.dif.FEV1/">
            <FECAESolicitarResult>
              <FeCabResp>
                <Cuit>20000000009</Cuit>
                <PtoVta>1</PtoVta>
                <CbteTipo>11</CbteTipo>
                <FchProceso>20240202090000</FchProceso>
                <CantReg>1</CantReg>
                <Resultado>A</Resultado>
                <Reproceso>N</Reproceso>
              </FeCabResp>
              <FeDetResp>
                <FECAEDetResponse>
                  <Concepto>2</Concepto>
                  <DocTipo>99</DocTipo>
                  <DocNro>0</DocNro>
                  <CbteDesde>#{invoice_number}</CbteDesde>
                  <CbteHasta>#{invoice_number}</CbteHasta>
                  <CbteFch>20240202</CbteFch>
                  <Resultado>A</Resultado>
                  <CAE>#{cae}</CAE>
                  <CAEFchVto>20240212</CAEFchVto>
                </FECAEDetResponse>
              </FeDetResp>
            </FECAESolicitarResult>
          </FECAESolicitarResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  def rejected_response_xml(error_msg: 'Numero de punto de venta incorrecto')
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <FECAESolicitarResponse xmlns="http://ar.gov.afip.dif.FEV1/">
            <FECAESolicitarResult>
              <FeCabResp>
                <Cuit>20000000009</Cuit>
                <PtoVta>1</PtoVta>
                <CbteTipo>11</CbteTipo>
                <FchProceso>20240202090000</FchProceso>
                <CantReg>1</CantReg>
                <Resultado>R</Resultado>
                <Reproceso>N</Reproceso>
              </FeCabResp>
              <FeDetResp>
                <FECAEDetResponse>
                  <Concepto>2</Concepto>
                  <DocTipo>99</DocTipo>
                  <DocNro>0</DocNro>
                  <CbteDesde>1</CbteDesde>
                  <CbteHasta>1</CbteHasta>
                  <CbteFch>20240202</CbteFch>
                  <Resultado>R</Resultado>
                  <Errors>
                    <Err>
                      <Code>10060</Code>
                      <Msg>#{error_msg}</Msg>
                    </Err>
                  </Errors>
                </FECAEDetResponse>
              </FeDetResp>
            </FECAESolicitarResult>
          </FECAESolicitarResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  describe '#call' do
    context 'when the invoice already has a CAE' do
      let(:invoice) { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }

      it 'returns the invoice early without calling AFIP' do
        service.call
        expect(WebMock).not_to have_requested(:post, afip_url)
      end

      it 'returns the invoice object' do
        result = service.call
        expect(result[:success]).to be true
      end
    end

    context 'when AFIP approves the invoice' do
      before do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: approved_response_xml, headers: { 'Content-Type' => 'text/xml' })
      end

      it 'returns success: true' do
        result = service.call
        expect(result[:success]).to be true
      end

      it 'sets the CAE on the invoice' do
        service.call
        expect(invoice.reload.cae).to eq('75109284616809')
      end

      it 'sets afip_result to "A"' do
        service.call
        expect(invoice.reload.afip_result).to eq('A')
      end

      it 'sets the CAE expiration date' do
        service.call
        expect(invoice.reload.cae_expiration).to eq(Date.parse('2024-02-12'))
      end

      it 'sets afip_authorized_at' do
        service.call
        expect(invoice.reload.afip_authorized_at).not_to be_nil
      end

      it 'persists the AFIP response XML' do
        service.call
        expect(invoice.reload.afip_response_xml).to be_present
      end
    end

    context 'when AFIP rejects the invoice' do
      let(:error_message) { 'Numero de punto de venta incorrecto' }

      before do
        stub_request(:post, afip_url)
          .to_return(status: 200, body: rejected_response_xml(error_msg: error_message),
                     headers: { 'Content-Type' => 'text/xml' })
      end

      it 'returns success: false' do
        result = service.call
        expect(result[:success]).to be false
      end

      it 'includes the error message' do
        result = service.call
        expect(result[:errors]).to eq(error_message)
      end

      it 'sets afip_result to "R"' do
        service.call
        expect(invoice.reload.afip_result).to eq('R')
      end

      it 'does not set a CAE' do
        service.call
        expect(invoice.reload.cae).to be_nil
      end
    end

    context 'when the SOAP call raises a network error' do
      before do
        stub_request(:post, afip_url)
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))
      end

      it 'raises a Faraday::ConnectionFailed error' do
        expect { service.call }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end
end
