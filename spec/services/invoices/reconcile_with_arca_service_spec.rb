require "rails_helper"

RSpec.describe Invoices::ReconcileWithArcaService, type: :service do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }
  let(:invoice) do
    create(:client_invoice, user: user, sell_point: sell_point, client: client,
           number: "5", invoice_type: "C", afip_status: :draft)
  end

  subject(:service) { described_class.new(invoice: invoice) }

  before do
    allow(Invoices::Development::AuthWithArcaService).to receive_message_chain(:new, :call)
      .and_return([ "fake_token", "fake_sign" ])
  end

  describe "#call" do
    context "when ARCA confirms the invoice was authorized" do
      let(:reconciliation_data) do
        {
          authorized:          true,
          cae:                 "71234567890123",
          cae_expiration:      Date.today + 10,
          afip_authorized_at:  Time.zone.now,
          afip_invoice_number: "5"
        }
      end

      before do
        allow_any_instance_of(Invoices::Development::FeCompConsultService).to receive(:call)
          .and_return(reconciliation_data)
      end

      it "returns authorized: true" do
        expect(service.call[:authorized]).to be true
      end

      it "persists the CAE on the invoice" do
        service.call
        expect(invoice.reload.cae).to eq("71234567890123")
      end

      it "sets afip_status to authorized" do
        service.call
        expect(invoice.reload.afip_status).to eq("authorized")
      end

      it "persists cae_expiration" do
        service.call
        expect(invoice.reload.cae_expiration).to eq(reconciliation_data[:cae_expiration])
      end

      it "persists afip_invoice_number" do
        service.call
        expect(invoice.reload.afip_invoice_number).to eq("5")
      end
    end

    context "when ARCA says the invoice was not authorized" do
      before do
        allow_any_instance_of(Invoices::Development::FeCompConsultService).to receive(:call)
          .and_return({ authorized: false, cae: nil })
      end

      it "returns authorized: false" do
        expect(service.call[:authorized]).to be false
      end

      it "does not change the invoice" do
        expect { service.call }.not_to change { invoice.reload.afip_status }
      end
    end

    context "when the network call times out" do
      before do
        allow_any_instance_of(Invoices::Development::FeCompConsultService).to receive(:call)
          .and_raise(Faraday::TimeoutError, "timeout")
      end

      it "re-raises the error" do
        expect { service.call }.to raise_error(Faraday::TimeoutError)
      end
    end
  end
end
