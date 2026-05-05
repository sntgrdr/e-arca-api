require "rails_helper"

RSpec.describe BatchArca::ProcessorService, type: :service do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }

  let!(:invoice1) { create(:client_invoice, user: user, sell_point: sell_point, client: client, number: "5", invoice_type: "C") }
  let!(:invoice2) { create(:client_invoice, user: user, sell_point: sell_point, client: client, number: "6", invoice_type: "C") }
  let!(:invoice3) { create(:client_invoice, user: user, sell_point: sell_point, client: client, number: "7", invoice_type: "C") }

  let(:batch) do
    b = create(:batch_arca_process, user: user, sell_point: sell_point, invoice_type: "C", total_invoices: 3)
    [invoice1, invoice2, invoice3].each { |inv| create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv) }
    b
  end

  let(:arca_success) { { success: true, invoice: invoice1 } }
  let(:arca_failure) { { success: false, errors: "Error 1234: Dato inválido" } }

  subject(:service) { described_class.new(batch) }

  before do
    allow(Invoices::Development::AuthWithArcaService).to receive_message_chain(:new, :call).and_return(["fake_token", "fake_sign"])
  end

  describe "#call" do
    context "when all invoices are authorized successfully" do
      before do
        allow_any_instance_of(Invoices::Development::SendToArcaService).to receive(:call).and_return(arca_success)
      end

      it "marks the batch as completed" do
        service.call
        expect(batch.reload.status).to eq("completed")
      end

      it "marks all join records as authorized" do
        service.call
        expect(batch.batch_arca_process_invoices.pluck(:arca_status).uniq).to eq(["authorized"])
      end

      it "increments processed_invoices to total" do
        service.call
        expect(batch.reload.processed_invoices).to eq(3)
      end
    end

    context "when the second invoice fails" do
      before do
        call_count = 0
        allow_any_instance_of(Invoices::Development::SendToArcaService).to receive(:call) do
          call_count += 1
          call_count == 1 ? arca_success : arca_failure
        end
        allow_any_instance_of(Invoices::Development::FeCompConsultarService).to receive(:call)
          .and_return({ authorized: false, cae: nil })
      end

      it "marks the batch as failed" do
        service.call
        expect(batch.reload.status).to eq("failed")
      end

      it "marks the failed invoice join record as failed" do
        service.call
        join = batch.batch_arca_process_invoices.find_by(invoice: invoice2)
        expect(join.arca_status).to eq("failed")
        expect(join.arca_error).to eq("Error 1234: Dato inválido")
      end

      it "marks subsequent invoices as blocked" do
        service.call
        join = batch.batch_arca_process_invoices.find_by(invoice: invoice3)
        expect(join.arca_status).to eq("blocked")
      end

      it "increments failed_invoices" do
        service.call
        expect(batch.reload.failed_invoices).to eq(1)
      end

      it "sets processed_invoices to the count that succeeded before the failure" do
        service.call
        expect(batch.reload.processed_invoices).to eq(1)
      end

      it "sets batch.error_message to the ARCA error string" do
        service.call
        expect(batch.reload.error_message).to eq("Error 1234: Dato inválido")
      end
    end

    context "when ARCA times out but invoice was actually authorized (reconciliation)" do
      before do
        allow_any_instance_of(Invoices::Development::SendToArcaService).to receive(:call)
          .and_raise(Faraday::TimeoutError, "timeout")
        allow_any_instance_of(Invoices::Development::FeCompConsultarService).to receive(:call)
          .and_return({
            authorized:          true,
            cae:                 "71234567890123",
            cae_expiration:      Date.today + 10,
            afip_authorized_at:  Time.zone.now,
            afip_invoice_number: "5"
          })
      end

      it "persists the CAE data on the invoice" do
        service.call
        invoice1.reload
        expect(invoice1.cae).to eq("71234567890123")
        expect(invoice1.afip_status).to eq("authorized")
      end

      it "marks the batch as completed" do
        service.call
        expect(batch.reload.status).to eq("completed")
      end

      it "marks all join records as authorized" do
        service.call
        expect(batch.batch_arca_process_invoices.pluck(:arca_status).uniq).to eq(["authorized"])
      end

      it "sets processed_invoices to total_invoices" do
        service.call
        expect(batch.reload.processed_invoices).to eq(3)
      end
    end

    context "when a join record is already authorized (retry idempotency)" do
      before do
        batch.batch_arca_process_invoices.find_by(invoice: invoice1).update!(arca_status: :authorized)
      end

      it "does not send invoice1 to ARCA again" do
        call_count = 0
        allow_any_instance_of(Invoices::Development::SendToArcaService).to receive(:call) do
          call_count += 1
          arca_success
        end
        service.call
        expect(call_count).to eq(2)
      end

      it "marks the batch as completed" do
        allow_any_instance_of(Invoices::Development::SendToArcaService).to receive(:call).and_return(arca_success)
        service.call
        expect(batch.reload.status).to eq("completed")
      end
    end
  end
end
