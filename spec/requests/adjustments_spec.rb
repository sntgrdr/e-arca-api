require 'rails_helper'

RSpec.describe "Adjustments API", type: :request do
  let(:user)    { create(:user, adjustments_enabled: true) }
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
          start_date:       Date.current.iso8601,
          active:           true,
          applicable_ids:   [ item.id ],
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

  describe "POST /api/v1/adjustments — fixed amount" do
    let(:iva)  { create(:iva, user: user, percentage: 21.0) }
    let(:item) { create(:item, user: user, iva: iva) }

    let(:fixed_params) do
      {
        adjustment: {
          adjustment_type:  "discount",
          calculation_type: "fixed",
          amount:           121.0,
          target_type:      "Client",
          target_id:        client.id,
          start_date:       Date.current.iso8601,
          active:           true,
          applicable_ids:   [ item.id ],
          applicable_type:  "Item"
        }
      }
    end

    it "strips IVA from the amount and sets iva_id automatically" do
      post "/api/v1/adjustments", params: fixed_params, headers: headers
      expect(response).to have_http_status(:created)
      adj = Adjustment.last
      expect(adj.amount).to be_within(0.0001).of(100.0)
      expect(adj.iva_id).to eq(iva.id)
    end

    it "returns the iva in the response" do
      post "/api/v1/adjustments", params: fixed_params, headers: headers
      body = response.parsed_body
      expect(body["iva"]["id"]).to eq(iva.id)
      expect(body["iva"]["percentage"].to_f).to eq(21.0)
    end

    context "when items have different IVA rates" do
      let(:iva2)  { create(:iva, user: user, percentage: 10.5) }
      let(:item2) { create(:item, user: user, iva: iva2) }

      it "returns 422 with an error message" do
        post "/api/v1/adjustments",
             params: fixed_params.deep_merge(adjustment: { applicable_ids: [ item.id, item2.id ] }),
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("mismo IVA")
      end
    end
  end

  describe "POST /api/v1/adjustments — date validations" do
    let(:item) { create(:item, user: user) }

    it "returns 422 when start_date is missing" do
      post "/api/v1/adjustments",
           params: { adjustment: {
             adjustment_type: "discount", calculation_type: "percentage", amount: 10.0,
             target_type: "Client", target_id: client.id,
             applicable_ids: [ item.id ], applicable_type: "Item"
           } },
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when end_date is before start_date" do
      post "/api/v1/adjustments",
           params: { adjustment: {
             adjustment_type: "discount", calculation_type: "percentage", amount: 10.0,
             target_type: "Client", target_id: client.id,
             start_date: Date.current.iso8601, end_date: 1.day.ago.to_date.iso8601,
             applicable_ids: [ item.id ], applicable_type: "Item"
           } },
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("no puede ser anterior")
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

  context "when adjustments_enabled is false" do
    let(:user)    { create(:user, adjustments_enabled: false) }
    let(:headers) { auth_headers(user) }

    it "returns 403 on index" do
      get "/api/v1/adjustments", headers: headers
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("feature_disabled")
    end

    it "returns 403 on create" do
      post "/api/v1/adjustments", params: { adjustment: { adjustment_type: "discount" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 on resolve" do
      item = create(:item, user: user)
      get "/api/v1/adjustments/resolve",
          params: { client_id: client.id, item_id: item.id },
          headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
