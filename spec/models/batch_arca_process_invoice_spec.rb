require "rails_helper"

RSpec.describe BatchArcaProcessInvoice, type: :model do
  let(:user)       { create(:user) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }
  let(:invoice)    { create(:client_invoice, user: user, sell_point: sell_point, client: client) }
  let(:batch)      { create(:batch_arca_process, user: user, sell_point: sell_point) }

  describe "validations" do
    it "is valid with required attributes" do
      join = build(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice)
      expect(join).to be_valid
    end

    it "requires arca_status" do
      join = build(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice, arca_status: nil)
      expect(join).not_to be_valid
    end
  end

  describe "arca_status enum" do
    it "defaults to pending" do
      join = create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice)
      expect(join).to be_pending
    end

    it "allows all expected statuses" do
      %w[pending processing authorized failed blocked].each do |status|
        join = build(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice, arca_status: status)
        expect(join).to be_valid
      end
    end
  end

  describe ".unprocessed" do
    let(:inv2) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }
    let(:inv3) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }
    let(:inv4) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }
    let(:inv5) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }

    let!(:pending_join)    { create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice, arca_status: :pending) }
    let!(:blocked_join)    { create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: inv2,    arca_status: :blocked) }
    let!(:authorized_join) { create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: inv3,    arca_status: :authorized) }
    let!(:processing_join) { create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: inv4,    arca_status: :processing) }
    let!(:failed_join)     { create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: inv5,    arca_status: :failed) }

    it "includes pending records" do
      expect(BatchArcaProcessInvoice.unprocessed).to include(pending_join)
    end

    it "includes blocked records" do
      expect(BatchArcaProcessInvoice.unprocessed).to include(blocked_join)
    end

    it "excludes authorized records" do
      expect(BatchArcaProcessInvoice.unprocessed).not_to include(authorized_join)
    end

    it "excludes processing records" do
      expect(BatchArcaProcessInvoice.unprocessed).not_to include(processing_join)
    end

    it "excludes failed records" do
      expect(BatchArcaProcessInvoice.unprocessed).not_to include(failed_join)
    end
  end
end
