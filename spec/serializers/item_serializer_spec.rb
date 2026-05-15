require "rails_helper"

RSpec.describe ItemSerializer, type: :serializer do
  let(:user)  { create(:user) }
  let(:iva)   { create(:iva, user: user, percentage: 21.0) }

  def serialized(item)
    described_class.new(item).serializable_hash.stringify_keys
  end

  describe "item with a group" do
    let(:group) { create(:item_group, user: user, name: "Electronics") }
    let(:item)  { create(:item, user: user, iva: iva, item_group: group, price: 121.0) }

    it "includes item_group_name" do
      expect(serialized(item)["item_group_name"]).to eq("Electronics")
    end

    it "does not embed a nested item_group object" do
      expect(serialized(item)).not_to have_key("item_group")
    end
  end

  describe "item without a group" do
    let(:item) { create(:item, user: user, iva: iva, item_group: nil, price: 121.0) }

    it "returns nil for item_group_name" do
      expect(serialized(item)["item_group_name"]).to be_nil
    end
  end
end
