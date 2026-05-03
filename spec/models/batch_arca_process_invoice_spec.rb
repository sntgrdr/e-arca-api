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

  describe ".unprocessed scope" do
    it "returns pending and blocked records" do
      pending_join   = create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: invoice, arca_status: :pending)
      create(:client_invoice, user: user, sell_point: sell_point, client: client).tap do |inv2|
        create(:batch_arca_process_invoice, batch_arca_process: batch, invoice: inv2, arca_status: :authorized)
      end
      expect(BatchArcaProcessInvoice.unprocessed).to include(pending_join)
    end
  end
end
