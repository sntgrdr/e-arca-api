require "rails_helper"

RSpec.describe "PATCH /api/v1/items/bulk_update_prices", type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva)     { create(:iva, user: user, percentage: 21) }
  let(:item1)   { create(:item, user: user, iva: iva, price: 100) }
  let(:item2)   { create(:item, user: user, iva: iva, price: 200) }

  let(:valid_params) do
    {
      items: [
        { id: item1.id, price: 121.0 },
        { id: item2.id, price: 242.0 }
      ]
    }
  end

  it "returns 200 and the updated items" do
    patch "/api/v1/items/bulk_update_prices",
          params: valid_params, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.map { |i| i["id"] }).to contain_exactly(item1.id, item2.id)
    expect(body.first).to include("price_with_iva")
  end

  it "stores price without IVA after update" do
    patch "/api/v1/items/bulk_update_prices",
          params: { items: [{ id: item1.id, price: 121.0 }] },
          headers: headers, as: :json
    expect(item1.reload.price.to_f.round(2)).to eq(100.0)
  end

  it "returns 422 when items list is empty" do
    patch "/api/v1/items/bulk_update_prices",
          params: { items: [] }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "message")).to match(/No items/)
  end

  it "returns 422 when a price is zero" do
    patch "/api/v1/items/bulk_update_prices",
          params: { items: [{ id: item1.id, price: 0 }] },
          headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 422 when a price is negative" do
    patch "/api/v1/items/bulk_update_prices",
          params: { items: [{ id: item1.id, price: -10 }] },
          headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 422 with count when over 100 items" do
    items_data = Array.new(101) { |i| { id: i + 1, price: 100 } }
    patch "/api/v1/items/bulk_update_prices",
          params: { items: items_data }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "message")).to match(/received 101/)
  end

  it "ignores items belonging to another user" do
    other_user = create(:user)
    other_item = create(:item, user: other_user, iva: iva, price: 100)
    patch "/api/v1/items/bulk_update_prices",
          params: { items: [{ id: item1.id, price: 121.0 }, { id: other_item.id, price: 121.0 }] },
          headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    ids = JSON.parse(response.body).map { |i| i["id"] }
    expect(ids).to contain_exactly(item1.id)
    expect(ids).not_to include(other_item.id)
  end

  it "returns 401 when not authenticated" do
    patch "/api/v1/items/bulk_update_prices",
          params: valid_params, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
