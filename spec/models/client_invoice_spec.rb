require 'rails_helper'

RSpec.describe ClientInvoice, type: :model do
  it { should validate_numericality_of(:total_price).is_greater_than(0) }
  it { should have_many(:credit_notes) }

  describe '#afip_code' do
    it 'returns correct codes' do
      invoice = build(:client_invoice, invoice_type: 'A')
      expect(invoice.afip_code).to eq('1')

      invoice.invoice_type = 'B'
      expect(invoice.afip_code).to eq('6')

      invoice.invoice_type = 'C'
      expect(invoice.afip_code).to eq('11')
    end
  end
end
