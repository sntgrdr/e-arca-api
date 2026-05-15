require "rails_helper"

RSpec.describe Items::BulkUpdatePricesService, type: :service do
  let(:user)  { create(:user) }
  let(:iva)   { create(:iva, user: user, percentage: 21) }
  let(:item1) { create(:item, user: user, iva: iva, price: 100) }
  let(:item2) { create(:item, user: user, iva: iva, price: 200) }
  let(:scope) { Item.where(user_id: user.id).active }

  def call(items_data)
    described_class.new(scope: scope, items_data: items_data).call
  end

  describe "#call" do
    it "returns success with updated items" do
      result = call([
        { id: item1.id, price: 121.0 },
        { id: item2.id, price: 242.0 }
      ])
      expect(result[:success]).to be true
      expect(result[:items].size).to eq(2)
    end

    it "back-calculates and stores price without IVA" do
      call([ { id: item1.id, price: 121.0 } ])
      # 121 / 1.21 = 100.0
      expect(item1.reload.price.to_f.round(2)).to eq(100.0)
    end

    it "returns error when items_data is empty" do
      result = call([])
      expect(result[:success]).to be false
      expect(result[:error]).to match(/No items/)
    end

    it "returns error when more than 100 items and includes received count" do
      items_data = Array.new(101) { |i| { id: i + 1, price: 100 } }
      result = call(items_data)
      expect(result[:success]).to be false
      expect(result[:error]).to match(/100/)
      expect(result[:error]).to match(/received 101/)
    end

    it "returns error when any price is zero" do
      result = call([ { id: item1.id, price: 0 } ])
      expect(result[:success]).to be false
      expect(result[:error]).to match(/greater than 0/)
    end

    it "returns error when any price is negative" do
      result = call([ { id: item1.id, price: -5 } ])
      expect(result[:success]).to be false
      expect(result[:error]).to match(/greater than 0/)
    end

    it "returns error when resolved item list is empty" do
      other_user = create(:user)
      other_item = create(:item, user: other_user, iva: iva, price: 100)
      result = call([ { id: other_item.id, price: 121 } ])
      expect(result[:success]).to be false
      expect(result[:error]).to match(/No valid items/)
    end

    it "silently skips IDs outside the scope" do
      other_user = create(:user)
      other_item = create(:item, user: other_user, iva: iva, price: 100)
      result = call([
        { id: item1.id, price: 121.0 },
        { id: other_item.id, price: 121.0 }
      ])
      expect(result[:success]).to be true
      expect(result[:items].map(&:id)).to contain_exactly(item1.id)
    end

    it "rolls back all updates if one item fails validation" do
      original_price = item1.reload.price

      allow_any_instance_of(Item).to receive(:update!).and_call_original
      allow_any_instance_of(Item).to receive(:update!)
        .with(price: 242.0)
        .and_raise(ActiveRecord::RecordInvalid.new(item2))

      result = call([
        { id: item1.id, price: 121.0 },
        { id: item2.id, price: 242.0 }
      ])
      expect(result[:success]).to be false
      expect(item1.reload.price).to eq(original_price)
    end

    it "excludes inactive items from the scope" do
      inactive_item = create(:item, user: user, iva: iva, price: 100, active: false)
      original_price = inactive_item.reload.price
      result = call([ { id: inactive_item.id, price: 121.0 } ])
      expect(result[:success]).to be false
      expect(result[:error]).to match(/No valid items/)
      expect(inactive_item.reload.price).to eq(original_price)
    end

    it "deduplicates repeated IDs and updates the item once" do
      result = call([
        { id: item1.id, price: 121.0 },
        { id: item1.id, price: 363.0 }
      ])
      expect(result[:success]).to be true
      expect(result[:items].map(&:id).uniq).to eq([ item1.id ])
    end
  end
end
