require 'rails_helper'

RSpec.describe Filters::ItemsFilterService, type: :service do
  subject(:filter) { described_class.new(params, scope).call }

  let(:user) { create(:user) }
  let(:scope) { Item.all }
  let(:iva_21)  { create(:iva, user: user, percentage: 21.0) }
  let(:iva_10)  { create(:iva, user: user, percentage: 10.5) }

  describe 'empty/nil params' do
    let!(:item_a) { create(:item, user: user) }
    let!(:item_b) { create(:item, user: user) }

    context 'when params is empty hash' do
      let(:params) { {} }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(item_a, item_b)
      end
    end

    context 'when params values are nil' do
      let(:params) { { code: nil, name: nil, iva_id: nil, price_from: nil, price_to: nil } }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(item_a, item_b)
      end
    end

    context 'when params values are blank strings' do
      let(:params) { { code: '', name: '', price_from: '', price_to: '' } }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(item_a, item_b)
      end
    end
  end

  describe '#filter_by_code' do
    let!(:widget) { create(:item, user: user, code: 'WIDGET-001') }
    let!(:gadget) { create(:item, user: user, code: 'GADGET-002') }

    context 'with a partial match' do
      let(:params) { { code: 'WIDGET' } }

      it 'returns only matching items' do
        expect(filter).to include(widget)
        expect(filter).not_to include(gadget)
      end
    end

    context 'with case-insensitive input' do
      let(:params) { { code: 'widget' } }

      it 'matches regardless of case' do
        expect(filter).to include(widget)
        expect(filter).not_to include(gadget)
      end
    end

    context 'with SQL injection attempt' do
      let(:params) { { code: "'; DROP TABLE items; --" } }

      it 'does not raise' do
        expect { filter.to_a }.not_to raise_error
      end
    end
  end

  describe '#filter_by_name' do
    let!(:service_item)  { create(:item, user: user, name: 'Consultoría mensual') }
    let!(:product_item)  { create(:item, user: user, name: 'Producto físico') }

    context 'with a partial match' do
      let(:params) { { name: 'consulto' } }

      it 'performs case-insensitive partial ILIKE matching' do
        expect(filter).to include(service_item)
        expect(filter).not_to include(product_item)
      end
    end
  end

  describe '#filter_by_iva_id' do
    let!(:item_21)  { create(:item, user: user, iva: iva_21) }
    let!(:item_10)  { create(:item, user: user, iva: iva_10) }

    context 'with a single iva_id' do
      let(:params) { { iva_id: [iva_21.id] } }

      it 'returns only items with the matching IVA' do
        expect(filter).to include(item_21)
        expect(filter).not_to include(item_10)
      end
    end

    context 'with multiple iva_ids' do
      let(:params) { { iva_id: [iva_21.id, iva_10.id] } }

      it 'returns items with any of the matching IVAs' do
        expect(filter).to include(item_21, item_10)
      end
    end
  end

  describe '#filter_by_price_from' do
    # The Item model divides price by (1 + iva%) on save, storing the net price.
    # Use a 0% IVA so the stored price equals the input price for predictable assertions.
    let(:iva_zero) { create(:iva, user: user, percentage: 0.0) }
    let!(:cheap)     { create(:item, user: user, price: 100.0,  iva: iva_zero) }
    let!(:mid)       { create(:item, user: user, price: 500.0,  iva: iva_zero) }
    let!(:expensive) { create(:item, user: user, price: 2000.0, iva: iva_zero) }

    context 'with a price_from value' do
      let(:params) { { price_from: '500' } }

      it 'returns items with stored price >= price_from' do
        expect(filter).to include(mid, expensive)
        expect(filter).not_to include(cheap)
      end
    end
  end

  describe '#filter_by_price_to' do
    let(:iva_zero) { create(:iva, user: user, percentage: 0.0) }
    let!(:cheap)     { create(:item, user: user, price: 100.0,  iva: iva_zero) }
    let!(:mid)       { create(:item, user: user, price: 500.0,  iva: iva_zero) }
    let!(:expensive) { create(:item, user: user, price: 2000.0, iva: iva_zero) }

    context 'with a price_to value' do
      let(:params) { { price_to: '500' } }

      it 'returns items with stored price <= price_to' do
        expect(filter).to include(cheap, mid)
        expect(filter).not_to include(expensive)
      end
    end
  end

  describe 'price range with both bounds' do
    let(:iva_zero) { create(:iva, user: user, percentage: 0.0) }
    let!(:cheap)     { create(:item, user: user, price: 100.0,  iva: iva_zero) }
    let!(:mid)       { create(:item, user: user, price: 500.0,  iva: iva_zero) }
    let!(:expensive) { create(:item, user: user, price: 2000.0, iva: iva_zero) }

    let(:params) { { price_from: '200', price_to: '1000' } }

    it 'returns only items within the price range' do
      expect(filter).to include(mid)
      expect(filter).not_to include(cheap, expensive)
    end
  end

  describe 'combined filters' do
    let(:iva_zero) { create(:iva, user: user, percentage: 0.0) }
    # Use 0% IVA for target so stored price == input price for assertion clarity
    let!(:target) { create(:item, user: user, code: 'SRV-001', name: 'Servicio Web', price: 3000.0, iva: iva_zero) }
    let!(:other)  { create(:item, user: user, code: 'PROD-002', name: 'Producto',     price: 100.0,  iva: iva_10) }

    let(:params) do
      {
        code: 'SRV',
        name: 'servicio',
        iva_id: [iva_zero.id],
        price_from: '2000',
        price_to: '5000'
      }
    end

    it 'applies all filters and returns the correct record' do
      expect(filter).to include(target)
      expect(filter).not_to include(other)
    end
  end
end
