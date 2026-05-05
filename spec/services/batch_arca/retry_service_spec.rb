require "rails_helper"

RSpec.describe BatchArca::RetryService, type: :service do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }

  let(:inv1) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }
  let(:inv2) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }
  let(:inv3) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }

  let(:batch) do
    b = create(:batch_arca_process, user: user, sell_point: sell_point,
               status: :failed, total_invoices: 3, processed_invoices: 1, failed_invoices: 1,
               error_message: "ARCA error")
    create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv1, arca_status: :authorized)
    create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv2, arca_status: :failed, arca_error: "Bad sequence")
    create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv3, arca_status: :blocked)
    b
  end

  before { allow(BatchArcaProcessJob).to receive(:perform_later) }

  subject(:result) { described_class.new(batch: batch).call }

  describe "#call" do
    it "returns success" do
      expect(result[:success]).to be true
    end

    it "returns the same batch" do
      expect(result[:batch].id).to eq(batch.id)
    end

    it "does not create a new BatchArcaProcess" do
      batch  # force lazy let evaluation before measuring count
      expect { described_class.new(batch: batch).call }.not_to change(BatchArcaProcess, :count)
    end

    it "resets failed join records to pending and clears arca_error" do
      result
      join = batch.batch_arca_process_invoices.find_by(invoice: inv2)
      expect(join.arca_status).to eq("pending")
      expect(join.arca_error).to be_nil
    end

    it "resets blocked join records to pending" do
      result
      join = batch.batch_arca_process_invoices.find_by(invoice: inv3)
      expect(join.arca_status).to eq("pending")
    end

    it "preserves authorized join records" do
      result
      join = batch.batch_arca_process_invoices.find_by(invoice: inv1)
      expect(join.arca_status).to eq("authorized")
    end

    it "sets batch status back to pending" do
      result
      expect(batch.reload.status).to eq("pending")
    end

    it "sets failed_invoices to 0" do
      result
      expect(batch.reload.failed_invoices).to eq(0)
    end

    it "sets error_message to nil" do
      result
      expect(batch.reload.error_message).to be_nil
    end

    it "sets processed_invoices to the count of already-authorized records" do
      result
      expect(batch.reload.processed_invoices).to eq(1)
    end

    it "enqueues BatchArcaProcessJob with the same batch id" do
      expect(BatchArcaProcessJob).to receive(:perform_later).with(batch.id)
      result
    end

    context "when there are no failed or blocked invoices" do
      let(:batch) do
        b = create(:batch_arca_process, user: user, sell_point: sell_point,
                   status: :failed, total_invoices: 1, processed_invoices: 1, failed_invoices: 0)
        create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv1, arca_status: :authorized)
        b
      end

      it "returns success without changing any join records" do
        expect(result[:success]).to be true
        expect(batch.batch_arca_process_invoices.pluck(:arca_status)).to eq([ "authorized" ])
      end

      it "re-enqueues the job" do
        expect(BatchArcaProcessJob).to receive(:perform_later).with(batch.id)
        result
      end

      it "sets processed_invoices to total_invoices" do
        result
        expect(batch.reload.processed_invoices).to eq(1)
      end
    end
  end
end
