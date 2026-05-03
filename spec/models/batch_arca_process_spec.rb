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
