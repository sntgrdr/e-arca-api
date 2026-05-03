require "rails_helper"

RSpec.describe Invoices::Production::FeCompConsultarService, type: :service do
  let(:service) do
    described_class.new(
      invoice_number: "5",
      sell_point_number: "1",
      afip_code: "11",
      legal_number: "20388864304"
    )
  end

  describe "#call" do
    context "when ARCA returns an authorized result" do
      before do
        stub_request(:post, described_class::URL)
          .to_return(
            status: 200,
            body: <<~XML
              <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                <soap:Body>
                  <FECompConsultarResponse xmlns="http://ar.gov.afip.dif.FEV1/">
                    <FECompConsultarResult>
                      <ResultGet>
                        <Resultado>A</Resultado>
                        <CAE>71234567890123</CAE>
                        <CAEFchVto>20260513</CAEFchVto>
                        <FchProceso>20260503101530</FchProceso>
                        <CbteDesde>5</CbteDesde>
                      </ResultGet>
                    </FECompConsultarResult>
                  </FECompConsultarResponse>
                </soap:Body>
              </soap:Envelope>
            XML
          )
        allow(Invoices::Production::AuthWithArcaService).to receive_message_chain(:new, :call).and_return(["token123", "sign123"])
      end

      it "returns authorized: true with CAE data" do
        result = service.call
        expect(result[:authorized]).to be true
        expect(result[:cae]).to eq("71234567890123")
        expect(result[:cae_expiration]).to eq(Date.new(2026, 5, 13))
        expect(result[:afip_authorized_at]).to be_a(Time)
        expect(result[:afip_invoice_number]).to eq("5")
      end
    end

    context "when ARCA returns not found" do
      before do
        stub_request(:post, described_class::URL)
          .to_return(
            status: 200,
            body: <<~XML
              <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                <soap:Body>
                  <FECompConsultarResponse xmlns="http://ar.gov.afip.dif.FEV1/">
                    <FECompConsultarResult>
                      <Errors>
                        <Err>
                          <Code>602</Code>
                          <Msg>No existen datos en nuestros registros</Msg>
                        </Err>
                      </Errors>
                    </FECompConsultarResult>
                  </FECompConsultarResponse>
                </soap:Body>
              </soap:Envelope>
            XML
          )
        allow(Invoices::Production::AuthWithArcaService).to receive_message_chain(:new, :call).and_return(["token123", "sign123"])
      end

      it "returns authorized: false" do
        result = service.call
        expect(result[:authorized]).to be false
        expect(result[:cae]).to be_nil
      end
    end

    context "when a network error occurs" do
      before do
        allow(Invoices::Production::AuthWithArcaService).to receive_message_chain(:new, :call).and_return(["token123", "sign123"])
        stub_request(:post, described_class::URL).to_raise(Faraday::TimeoutError)
      end

      it "re-raises the network error" do
        expect { service.call }.to raise_error(Faraday::TimeoutError)
      end
    end
  end
end
