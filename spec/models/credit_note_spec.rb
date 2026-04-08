require 'rails_helper'

RSpec.describe CreditNote, type: :model do
  it { should belong_to(:client_invoice) }

  describe '#afip_code' do
    let(:user) { create(:user) }
    let(:iva) { create(:iva, user: user) }
    let(:client) { create(:client, user: user, iva: iva) }
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client_invoice) { create(:client_invoice, user: user, client: client, sell_point: sell_point) }
    let(:credit_note) { build(:credit_note, user: user, client: client, sell_point: sell_point, client_invoice: client_invoice, invoice_type: 'A') }

    it 'returns correct codes' do
      expect(credit_note.afip_code).to eq('3')

      credit_note.invoice_type = 'B'
      expect(credit_note.afip_code).to eq('8')

      credit_note.invoice_type = 'C'
      expect(credit_note.afip_code).to eq('13')
    end
  end
end
