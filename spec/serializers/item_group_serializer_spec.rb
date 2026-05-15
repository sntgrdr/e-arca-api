require "rails_helper"

RSpec.describe ItemGroupSerializer, type: :serializer do
  let(:user)  { create(:user) }
  let(:group) { create(:item_group, user: user, name: "Electronics") }

  def serialized(record)
    described_class.new(record).serializable_hash.stringify_keys
  end

  it "includes id, name, active, details, and items_count" do
    result = serialized(group)
    expect(result.keys).to include("id", "name", "active", "details", "items_count")
  end

  it "returns the correct items_count" do
    create(:item, user: user, item_group: group)
    create(:item, user: user, item_group: group)
    expect(serialized(group)["items_count"]).to eq(2)
  end
end
