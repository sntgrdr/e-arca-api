require 'rails_helper'

RSpec.describe "GET /api/v1/adjustments/resolve", type: :request do
  let(:user)    { create(:user, adjustments_enabled: true) }
  let(:client)  { create(:client, user: user) }
  let(:iva)     { create(:iva, user: user, percentage: 21.0) }
  let(:item)    { create(:item, user: user, iva: iva, price: 1210.0) }
  let(:headers) { auth_headers(user) }

  context 'when no adjustments exist' do
    it 'returns nil for both discount and surcharge' do
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id },
          headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["discount"]).to be_nil
      expect(body["surcharge"]).to be_nil
    end
  end

  context 'when a discount exists for this client and item' do
    let!(:adj) do
      a = create(:adjustment, user: user, target: client,
                 adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0)
      create(:adjustment_applicable, adjustment: a, applicable: item)
      a
    end

    it 'returns the discount adjustment id' do
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id },
          headers: headers
      expect(response.parsed_body["discount"]["id"]).to eq(adj.id)
    end
  end

  context 'when a surcharge exists for this client and item' do
    let!(:adj) do
      a = create(:adjustment, user: user, target: client,
                 adjustment_type: 'surcharge', calculation_type: 'percentage', amount: 5.0)
      create(:adjustment_applicable, adjustment: a, applicable: item)
      a
    end

    it 'returns the surcharge adjustment id' do
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id },
          headers: headers
      expect(response.parsed_body["surcharge"]["id"]).to eq(adj.id)
    end
  end

  context 'with an optional date param' do
    let!(:future_adj) do
      a = create(:adjustment, user: user, target: client,
                 adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0,
                 start_date: 1.month.from_now)
      create(:adjustment_applicable, adjustment: a, applicable: item)
      a
    end

    it 'returns nil when the date is before the adjustment start_date' do
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id, date: Date.current.iso8601 },
          headers: headers
      expect(response.parsed_body["discount"]).to be_nil
    end

    it 'returns the adjustment when the date matches its validity range' do
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id, date: 2.months.from_now.to_date.iso8601 },
          headers: headers
      expect(response.parsed_body["discount"]["id"]).to eq(future_adj.id)
    end
  end

  it 'returns 401 when unauthenticated' do
    get "/api/v1/adjustments/resolve", params: { client_id: client.id, item_id: item.id }
    expect(response).to have_http_status(:unauthorized)
  end

  context 'when adjustments_enabled is false' do
    let(:user) { create(:user, adjustments_enabled: false) }

    it 'returns 403 with feature_disabled code' do
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id },
          headers: headers
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("feature_disabled")
    end
  end
end
