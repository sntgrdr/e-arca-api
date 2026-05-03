require "rails_helper"

RSpec.describe BatchArca::CreateService, type: :service do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }

  let(:invoices) do
    create_list(:client_invoice, 3, user: user, sell_point: sell_point, client: client,
                invoice_type: "C", afip_status: :draft)
  end

  subject(:service) do
    described_class.new(
      user:            user,
      invoice_ids:     invoices.map(&:id),
      invoice_class:   "ClientInvoice",
      idempotency_key: "test-key-123"
    )
  end

  before do
    # Stub job so it doesn't actually run
    allow(BatchArcaProcessJob).to receive(:perform_later)
  end

  describe "#call" do
    it "creates a BatchArcaProcess with the correct attributes" do
      result = service.call
      expect(result[:success]).to be true
      expect(result[:batch]).to be_a(BatchArcaProcess)
      expect(result[:batch]).to be_persisted
      expect(result[:batch].total_invoices).to eq(3)
      expect(result[:batch].status).to eq("pending")
      expect(result[:batch].sell_point_id).to eq(sell_point.id)
      expect(result[:batch].invoice_type).to eq("C")
    end

    it "creates BatchArcaProcessInvoice records for each invoice" do
      result = service.call
      expect(result[:batch].batch_arca_process_invoices.count).to eq(3)
      expect(result[:batch].batch_arca_process_invoices.map(&:arca_status).uniq).to eq(["pending"])
    end

    it "enqueues a BatchArcaProcessJob" do
      expect(BatchArcaProcessJob).to receive(:perform_later).once
      service.call
    end

    context "when invoices belong to different sell points" do
      let(:other_sell_point) { create(:sell_point, user: user) }
      let(:mixed_invoices) do
        [
          create(:client_invoice, user: user, sell_point: sell_point, client: client, invoice_type: "C"),
          create(:client_invoice, user: user, sell_point: other_sell_point, client: client, invoice_type: "C")
        ]
      end

      it "returns an error without creating a batch" do
        result = described_class.new(
          user:            user,
          invoice_ids:     mixed_invoices.map(&:id),
          invoice_class:   "ClientInvoice",
          idempotency_key: "test-key-456"
        ).call

        expect(result[:success]).to be false
        expect(result[:error]).to match(/same sell point/)
        expect(BatchArcaProcess.count).to eq(0)
      end
    end

    context "when invoices have different invoice_type" do
      let(:mixed_type_invoices) do
        [
          create(:client_invoice, user: user, sell_point: sell_point, client: client, invoice_type: "C"),
          create(:client_invoice, user: user, sell_point: sell_point, client: client, invoice_type: "B")
        ]
      end

      it "returns an error" do
        result = described_class.new(
          user:            user,
          invoice_ids:     mixed_type_invoices.map(&:id),
          invoice_class:   "ClientInvoice",
          idempotency_key: "test-key-789"
        ).call

        expect(result[:success]).to be false
        expect(result[:error]).to match(/same.*invoice type/i)
      end
    end

    context "when invoice count exceeds 100" do
      it "returns an error" do
        ids = Array.new(101) { |i| i + 1 }
        result = described_class.new(
          user: user, invoice_ids: ids,
          invoice_class: "ClientInvoice", idempotency_key: "test-key-overflow"
        ).call

        expect(result[:success]).to be false
        expect(result[:error]).to match(/100/)
      end
    end

    context "when idempotency_key was already used" do
      before { service.call }

      it "returns the existing batch without creating a new one" do
        expect {
          result = described_class.new(
            user:            user,
            invoice_ids:     invoices.map(&:id),
            invoice_class:   "ClientInvoice",
            idempotency_key: "test-key-123"
          ).call
          expect(result[:success]).to be true
        }.not_to change(BatchArcaProcess, :count)
      end
    end
  end
end
