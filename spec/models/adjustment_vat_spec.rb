require 'rails_helper'

RSpec.describe Adjustment, type: :model do
  describe 'VAT stripping on fixed amount update' do
    let(:user)   { create(:user) }
    let(:client) { create(:client, user: user) }
    let(:iva)    { create(:iva, user: user, percentage: 21.0) }
    let(:item)   { create(:item, user: user, iva: iva, price: 1210.0) }

    it 'strips IVA from fixed amount when updating amount on an item-scoped adjustment' do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'fixed', amount: 100.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)

      adj.reload
      adj.update!(amount: 121.0)

      expect(adj.reload.amount).to be_within(0.01).of(100.0)
    end

    it 'does not strip IVA on percentage adjustments' do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)

      adj.reload
      adj.update!(amount: 15.0)

      expect(adj.reload.amount).to eq(15.0)
    end
  end
end
