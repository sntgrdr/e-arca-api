require 'rails_helper'

RSpec.describe Adjustments::ResolveService, type: :service do
  let(:user)         { create(:user) }
  let(:client_group) { create(:client_group, user: user) }
  let(:client)       { create(:client, user: user, client_group: client_group) }
  let(:item_group)   { create(:item_group, user: user) }
  let(:iva)          { create(:iva, user: user, percentage: 21.0) }
  let(:item)         { create(:item, user: user, item_group: item_group, price: 1210.0, iva: iva) }

  def resolve(type)
    described_class.new(user: user, client: client, item: item, date: Date.current).call[type]
  end

  context 'when no adjustments exist' do
    it 'returns nil for discount' do
      expect(resolve(:discount)).to be_nil
    end

    it 'returns nil for surcharge' do
      expect(resolve(:surcharge)).to be_nil
    end
  end

  context 'priority: client > client_group for discount' do
    let!(:group_adj) do
      adj = create(:adjustment, user: user, target: client_group,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 5.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end
    let!(:client_adj) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end

    it 'returns the client adjustment over the client_group one' do
      expect(resolve(:discount)).to eq(client_adj)
    end
  end

  context 'priority: item > item_group > global' do
    let!(:global_adj) do
      create(:adjustment, user: user, target: client,
             adjustment_type: 'discount', calculation_type: 'percentage', amount: 5.0)
    end
    let!(:group_adj) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 8.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item_group)
      adj
    end
    let!(:item_adj) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 12.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end

    it 'returns the item-level adjustment' do
      expect(resolve(:discount)).to eq(item_adj)
    end
  end

  context 'tie-breaker: highest id wins within same scope' do
    let!(:older) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 5.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end
    let!(:newer) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end

    it 'returns the higher id adjustment' do
      expect(resolve(:discount).id).to eq(newer.id)
    end
  end

  context 'ignores inactive adjustments' do
    let!(:inactive) do
      adj = create(:adjustment, user: user, target: client, active: false,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end

    it 'returns nil' do
      expect(resolve(:discount)).to be_nil
    end
  end

  context 'ignores expired adjustments' do
    let!(:expired) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0,
                   start_date: 1.month.ago, end_date: 1.day.ago)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end

    it 'returns nil' do
      expect(resolve(:discount)).to be_nil
    end
  end

  context 'ignores soft-deleted adjustments' do
    let!(:deleted) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj.discard
      adj
    end

    it 'returns nil' do
      expect(resolve(:discount)).to be_nil
    end
  end

  context 'discount and surcharge resolved independently' do
    let!(:discount_adj) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end
    let!(:surcharge_adj) do
      adj = create(:adjustment, user: user, target: client,
                   adjustment_type: 'surcharge', calculation_type: 'percentage', amount: 5.0)
      create(:adjustment_applicable, adjustment: adj, applicable: item)
      adj
    end

    it 'returns both' do
      result = described_class.new(user: user, client: client, item: item, date: Date.current).call
      expect(result[:discount]).to eq(discount_adj)
      expect(result[:surcharge]).to eq(surcharge_adj)
    end
  end
end
