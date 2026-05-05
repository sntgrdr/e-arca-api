require "rails_helper"

RSpec.describe BatchArcaProcess, type: :model do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }

  describe "validations" do
    it "is valid with all required attributes" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point)
      expect(batch).to be_valid
    end

    it "requires invoice_class" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point, invoice_class: nil)
      expect(batch).not_to be_valid
      expect(batch.errors[:invoice_class]).to be_present
    end

    it "requires invoice_type" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point, invoice_type: nil)
      expect(batch).not_to be_valid
    end

    it "only allows ClientInvoice or CreditNote as invoice_class" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point, invoice_class: "InvalidClass")
      expect(batch).not_to be_valid
      expect(batch.errors[:invoice_class]).to be_present
    end
  end

  describe "status enum" do
    it "defaults to pending" do
      batch = create(:batch_arca_process, user: user, sell_point: sell_point)
      expect(batch).to be_pending
    end

    it "transitions through pending -> processing -> completed" do
      batch = create(:batch_arca_process, user: user, sell_point: sell_point)
      batch.update!(status: :processing)
      expect(batch).to be_processing
      batch.update!(status: :completed)
      expect(batch).to be_completed
    end
  end

  describe ".not_all_invoices_failed" do
    let(:iva)    { create(:iva, user: user) }
    let(:client) { create(:client, user: user, iva: iva) }

    def make_batch_with(*statuses)
      b = create(:batch_arca_process, user: user, sell_point: sell_point,
                 total_invoices: statuses.size, status: :failed)
      statuses.each do |s|
        inv = create(:client_invoice, user: user, sell_point: sell_point, client: client)
        create(:batch_arca_process_invoice, batch_arca_process: b, invoice: inv, arca_status: s)
      end
      b
    end

    it "includes batches with no join records (total_invoices: 0)" do
      batch = create(:batch_arca_process, user: user, sell_point: sell_point, total_invoices: 0)
      expect(BatchArcaProcess.not_all_invoices_failed).to include(batch)
    end

    it "includes batches with at least one authorized invoice" do
      batch = make_batch_with(:authorized, :failed)
      expect(BatchArcaProcess.not_all_invoices_failed).to include(batch)
    end

    it "includes batches with at least one blocked invoice" do
      batch = make_batch_with(:failed, :blocked)
      expect(BatchArcaProcess.not_all_invoices_failed).to include(batch)
    end

    it "includes batches with at least one pending invoice" do
      batch = make_batch_with(:failed, :pending)
      expect(BatchArcaProcess.not_all_invoices_failed).to include(batch)
    end

    it "excludes batches where every invoice is failed" do
      batch = make_batch_with(:failed, :failed)
      expect(BatchArcaProcess.not_all_invoices_failed).not_to include(batch)
    end

    it "excludes a single-invoice batch where that invoice is failed" do
      batch = make_batch_with(:failed)
      expect(BatchArcaProcess.not_all_invoices_failed).not_to include(batch)
    end
  end

  describe "#invoices_ordered" do
    let(:iva)    { create(:iva, user: user) }
    let(:client) { create(:client, user: user, iva: iva) }

    it "sorts invoices numerically, not lexicographically" do
      batch = create(:batch_arca_process, user: user, sell_point: sell_point, total_invoices: 3)
      [ 10, 2, 9 ].each do |n|
        inv = create(:client_invoice, user: user, sell_point: sell_point, client: client, number: n.to_s)
        create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: inv)
      end
      expect(batch.invoices_ordered.map(&:number)).to eq(%w[2 9 10])
    end
  end

  describe "#retryable?" do
    it "returns true when status is failed" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point, status: :failed)
      expect(batch.retryable?).to be true
    end

    it "returns false when status is completed" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point, status: :completed)
      expect(batch.retryable?).to be false
    end

    it "returns false when status is processing" do
      batch = build(:batch_arca_process, user: user, sell_point: sell_point, status: :processing)
      expect(batch.retryable?).to be false
    end
  end
end
