require 'rails_helper'

RSpec.describe Invoice, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:client) }
  it { should belong_to(:sell_point) }
  it { should have_many(:lines) }
  it { should validate_presence_of(:number) }
  it { should validate_presence_of(:date) }

  describe '.current_number' do
    let(:user) { create(:user) }
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client) { create(:client, user: user) }

    it 'returns next number as string' do
      create(:client_invoice, user: user, sell_point: sell_point, client: client, number: '5')
      expect(ClientInvoice.current_number(user.id, sell_point.id)).to eq('6')
    end

    it 'returns 1 when no invoices exist' do
      expect(ClientInvoice.current_number(user.id, sell_point.id)).to eq('1')
    end
  end
end
