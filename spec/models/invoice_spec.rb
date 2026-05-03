require 'rails_helper'

RSpec.describe Invoice, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:client) }
  it { should belong_to(:sell_point) }
  it { should have_many(:lines) }
  it { should validate_presence_of(:number) }
  it { should validate_presence_of(:date) }

  describe "#arca_locked?" do
    let(:user)       { create(:user) }
    let(:sell_point) { create(:sell_point, user: user) }
    let(:iva)        { create(:iva, user: user) }
    let(:client)     { create(:client, user: user, iva: iva) }

    subject(:invoice) { create(:client_invoice, user: user, sell_point: sell_point, client: client) }

    it "returns false when no ARCA fields are set" do
      expect(invoice.arca_locked?).to be false
    end

    it "returns true when cae is present" do
      invoice.cae = "71234567890123"
      expect(invoice.arca_locked?).to be true
    end

    it "returns true when afip_authorized_at is present" do
      invoice.afip_authorized_at = Time.zone.now
      expect(invoice.arca_locked?).to be true
    end

    it "returns true when afip_invoice_number is present" do
      invoice.afip_invoice_number = "5"
      expect(invoice.arca_locked?).to be true
    end
  end

  describe '.current_number' do
    let(:user) { create(:user) }
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client) { create(:client, user: user) }

    it 'returns next number as string' do
      create(:client_invoice, :with_lines, user: user, sell_point: sell_point, client: client, number: '5', invoice_type: 'C')
      expect(ClientInvoice.current_number(user.id, sell_point.id, 'C')).to eq('6')
    end

    it 'returns 1 when no invoices exist' do
      expect(ClientInvoice.current_number(user.id, sell_point.id, 'C')).to eq('1')
    end
  end
end
