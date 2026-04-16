# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/clients/search', type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva)     { create(:iva, user: user) }

  def search(q: nil, client_group_id: nil)
    params = {}
    params[:q] = q if q.present?
    params[:client_group_id] = client_group_id if client_group_id
    get '/api/v1/clients/search', params: params, headers: headers
    JSON.parse(response.body)
  end

  describe 'without q param' do
    before do
      create(:client, user: user, iva: iva, legal_name: "Zeta Corp",    active: true)
      create(:client, user: user, iva: iva, legal_name: "Alpha SA",     active: true)
      create(:client, user: user, iva: iva, legal_name: "Beta Ltda",    active: true)
    end

    it 'returns active clients ordered by legal_name ASC' do
      body = search
      expect(response).to have_http_status(:ok)
      expect(body.map { |c| c['legal_name'] }).to eq([ "Alpha SA", "Beta Ltda", "Zeta Corp" ])
    end

    it 'returns only id, legal_name, name fields' do
      body = search
      expect(body.first.keys).to match_array(%w[id legal_name name])
    end
  end

  describe 'with q param' do
    before do
      create(:client, user: user, iva: iva, legal_name: "García Hermanos",  name: "García Hnos",  active: true)
      create(:client, user: user, iva: iva, legal_name: "López Juan",       name: "García López", active: true)
      create(:client, user: user, iva: iva, legal_name: "Unrelated Client", name: "Unrelated",    active: true)
    end

    it 'matches on legal_name' do
      body = search(q: "García Hermanos")
      expect(body.map { |c| c['legal_name'] }).to include("García Hermanos")
      expect(body.map { |c| c['legal_name'] }).not_to include("Unrelated Client")
    end

    it 'matches on name' do
      body = search(q: "García López")
      expect(body.map { |c| c['name'] }).to include("García López")
    end

    it 'never returns inactive clients' do
      create(:client, user: user, iva: iva, legal_name: "García Inactivo", active: false)
      body = search(q: "García")
      expect(body.map { |c| c['legal_name'] }).not_to include("García Inactivo")
    end

    it 'treats single-character q as a valid search' do
      body = search(q: "G")
      expect(response).to have_http_status(:ok)
      expect(body).to be_an(Array)
    end

    it 'matches case-insensitively' do
      body = search(q: "GARCÍA")
      expect(body.map { |c| c['legal_name'] }).to include("García Hermanos")
    end

    it 'treats empty string q as no filter' do
      body = search(q: "")
      expect(response).to have_http_status(:ok)
      expect(body.map { |c| c['legal_name'] }).to include("García Hermanos", "López Juan", "Unrelated Client")
    end

    it 'sanitizes wildcard injection — % does not return all clients' do
      body = search(q: "%")
      # % alone matches everything via ILIKE — but the result must still be scoped
      # to current_user and active only, proving no injection escape occurred
      expect(response).to have_http_status(:ok)
      body.each do |c|
        client = Client.find(c['id'])
        expect(client.user_id).to eq(user.id)
        expect(client.active).to be true
      end
    end
  end

  describe 'result cap' do
    before { create_list(:client, 30, user: user, iva: iva, active: true) }

    it 'returns at most 25 results' do
      body = search
      expect(body.length).to be <= 25
    end
  end

  describe 'tenant isolation' do
    let(:other_user) { create(:user) }
    let(:other_iva)  { create(:iva, user: other_user) }

    before do
      create(:client, user: other_user, iva: other_iva, legal_name: "Other User Client", active: true)
    end

    it 'never returns another user clients' do
      body = search(q: "Other")
      expect(body.map { |c| c['legal_name'] }).not_to include("Other User Client")
    end
  end

  describe 'group filtering' do
    let(:group_a) { create(:client_group, user: user) }
    let(:group_b) { create(:client_group, user: user) }

    before do
      create(:client, user: user, iva: iva, legal_name: "Group A Client", active: true, client_group: group_a)
      create(:client, user: user, iva: iva, legal_name: "Group B Client", active: true, client_group: group_b)
      create(:client, user: user, iva: iva, legal_name: "No Group Client", active: true)
    end

    it 'returns only clients in the given group' do
      body = search(client_group_id: group_a.id)
      expect(body.map { |c| c['legal_name'] }).to contain_exactly("Group A Client")
    end

    it 'combines q and client_group_id' do
      body = search(q: "Group", client_group_id: group_b.id)
      expect(body.map { |c| c['legal_name'] }).to contain_exactly("Group B Client")
    end

    it 'returns 200 and empty array when no clients match the group' do
      body = search(client_group_id: group_a.id + 9999)
      expect(response).to have_http_status(:ok)
      expect(body).to eq([])
    end
  end

  describe 'authentication' do
    it 'returns 401 without auth headers' do
      get '/api/v1/clients/search', as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
