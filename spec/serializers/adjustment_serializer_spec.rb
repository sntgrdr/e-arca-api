require 'rails_helper'

RSpec.describe AdjustmentSerializer, type: :serializer do
  let(:user)   { create(:user) }
  let(:client) { create(:client, user: user) }

  def serialized(adjustment)
    described_class.new(adjustment).serializable_hash.stringify_keys
  end

  describe 'applicable_names' do
    context 'with item applicables' do
      let(:item_a) { create(:item, user: user, name: 'Servicio A') }
      let(:item_b) { create(:item, user: user, name: 'Servicio B') }
      let(:adj) do
        a = create(:adjustment, user: user, target: client)
        create(:adjustment_applicable, adjustment: a, applicable: item_a)
        create(:adjustment_applicable, adjustment: a, applicable: item_b)
        a.reload
      end

      it 'returns the item names' do
        names = serialized(adj)['applicable_names']
        expect(names).to include('Servicio A', 'Servicio B')
      end
    end

    context 'with item_group applicable' do
      let(:group) { create(:item_group, user: user, name: 'Grupo Premium') }
      let(:adj) do
        a = create(:adjustment, user: user, target: client)
        create(:adjustment_applicable, adjustment: a, applicable: group)
        a.reload
      end

      it 'returns the group name' do
        names = serialized(adj)['applicable_names']
        expect(names).to eq([ 'Grupo Premium' ])
      end
    end

    context 'with no applicables (global)' do
      let(:adj) { create(:adjustment, user: user, target: client) }

      it 'returns empty array' do
        expect(serialized(adj)['applicable_names']).to eq([])
      end
    end

    context 'when an applicable item has been deleted' do
      let(:item_a) { create(:item, user: user, name: 'Servicio A') }
      let(:item_b) { create(:item, user: user, name: 'Servicio B') }
      let(:adj) do
        a = create(:adjustment, user: user, target: client)
        create(:adjustment_applicable, adjustment: a, applicable: item_a)
        create(:adjustment_applicable, adjustment: a, applicable: item_b)
        a.reload
      end

      it 'excludes the destroyed item from names' do
        item_b.destroy!
        names = serialized(adj)['applicable_names']
        expect(names).to include('Servicio A')
        expect(names).not_to include('Servicio B')
      end
    end
  end
end
