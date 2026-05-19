require 'rails_helper'

RSpec.describe "Adjustments API", type: :request do
  let(:user)    { create(:user) }
  let(:client)  { create(:client, user: user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/adjustments" do
    let!(:adj)   { create(:adjustment, user: user, target: client) }
    let!(:other) { create(:adjustment) }

    it "returns only the current user's adjustments" do
      get "/api/v1/adjustments", headers: headers
      ids = response.parsed_body["data"].map { |a| a["id"] }
      expect(ids).to include(adj.id)
      expect(ids).not_to include(other.id)
    end

    it "returns 200" do
      get "/api/v1/adjustments", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 401 when unauthenticated" do
      get "/api/v1/adjustments"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/adjustments" do
    let(:item) { create(:item, user: user) }
    let(:valid_params) do
      {
        adjustment: {
          adjustment_type:  "discount",
          calculation_type: "percentage",
          amount:           10.0,
          target_type:      "Client",
          target_id:        client.id,
          active:           true,
          applicable_ids:   [item.id],
          applicable_type:  "Item"
        }
      }
    end

    it "creates an adjustment and returns 201" do
      expect {
        post "/api/v1/adjustments", params: valid_params, headers: headers
      }.to change(Adjustment, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "creates adjustment_applicables for the given items" do
      post "/api/v1/adjustments", params: valid_params, headers: headers
      adj = Adjustment.last
      expect(adj.adjustment_applicables.count).to eq(1)
      expect(adj.adjustment_applicables.first.applicable_id).to eq(item.id)
    end

    it "returns 422 for invalid params" do
      post "/api/v1/adjustments",
           params: { adjustment: { adjustment_type: "discount", calculation_type: "percentage", amount: -1,
                                   target_type: "Client", target_id: client.id } },
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 when unauthenticated" do
      post "/api/v1/adjustments", params: valid_params
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/adjustments/:id" do
    let!(:adj) { create(:adjustment, user: user, target: client) }

    it "updates and returns the adjustment" do
      patch "/api/v1/adjustments/#{adj.id}", params: { adjustment: { amount: 15.0 } }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(adj.reload.amount).to be_within(0.001).of(15.0)
    end

    it "returns 404 for another user's adjustment" do
      other_adj = create(:adjustment)
      patch "/api/v1/adjustments/#{other_adj.id}", params: { adjustment: { amount: 5 } }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/adjustments/:id" do
    let!(:adj) { create(:adjustment, user: user, target: client) }

    it "soft-deletes and returns 204" do
      delete "/api/v1/adjustments/#{adj.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(adj.reload.deleted_at).not_to be_nil
    end
  end

  describe "PATCH /api/v1/adjustments/:id/deactivate" do
    let!(:adj) { create(:adjustment, user: user, target: client, active: true) }

    it "sets active to false" do
      patch "/api/v1/adjustments/#{adj.id}/deactivate", headers: headers
      expect(response).to have_http_status(:ok)
      expect(adj.reload.active).to be false
    end
  end

  describe "PATCH /api/v1/adjustments/:id/reactivate" do
    let!(:adj) { create(:adjustment, user: user, target: client, active: false) }

    it "sets active to true" do
      patch "/api/v1/adjustments/#{adj.id}/reactivate", headers: headers
      expect(response).to have_http_status(:ok)
      expect(adj.reload.active).to be true
    end
  end
end
