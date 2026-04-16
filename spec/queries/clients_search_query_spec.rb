# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClientsSearchQuery do
  let(:user) { create(:user) }
  let(:iva)  { create(:iva, user: user) }

  def query(q: nil, limit: 25, client_group_id: nil)
    described_class.call(q: q, current_user: user, limit: limit, client_group_id: client_group_id)
  end

  describe 'tenant scoping' do
    let(:other_user) { create(:user) }
    let(:other_iva)  { create(:iva, user: other_user) }

    before do
      create(:client, user: user,       iva: iva,       legal_name: "My Client",    active: true)
      create(:client, user: other_user, iva: other_iva, legal_name: "Other Client", active: true)
    end

    it 'returns only the current user clients' do
      expect(query.map(&:legal_name)).to contain_exactly("My Client")
    end
  end

  describe 'active filtering' do
    before do
      create(:client, user: user, iva: iva, legal_name: "Active One",   active: true)
      create(:client, user: user, iva: iva, legal_name: "Inactive One", active: false)
    end

    it 'excludes inactive clients' do
      expect(query.map(&:legal_name)).to contain_exactly("Active One")
    end
  end

  describe 'ordering' do
    before do
      create(:client, user: user, iva: iva, legal_name: "Zeta",  active: true)
      create(:client, user: user, iva: iva, legal_name: "Alpha", active: true)
      create(:client, user: user, iva: iva, legal_name: "Beta",  active: true)
    end

    it 'returns results ordered by legal_name ASC' do
      expect(query.map(&:legal_name)).to eq([ "Alpha", "Beta", "Zeta" ])
    end
  end

  describe 'limit' do
    before { create_list(:client, 10, user: user, iva: iva, active: true) }

    it 'respects the limit parameter' do
      expect(query(limit: 3).to_a.length).to eq(3)
    end

    it 'defaults to 25' do
      create_list(:client, 20, user: user, iva: iva, active: true)
      expect(query.to_a.length).to eq(25)
    end
  end

  describe 'search filtering' do
    before do
      create(:client, user: user, iva: iva, legal_name: "García Hermanos", name: "García Hnos",  active: true)
      create(:client, user: user, iva: iva, legal_name: "López Juan",      name: "García López", active: true)
      create(:client, user: user, iva: iva, legal_name: "Unrelated",       name: "Unrelated",    active: true)
    end

    context 'when q is nil' do
      it 'returns all active clients' do
        expect(query(q: nil).count).to eq(3)
      end
    end

    context 'when q is an empty string' do
      it 'returns all active clients' do
        expect(query(q: "").count).to eq(3)
      end
    end

    context 'when q matches legal_name' do
      it 'returns matching clients' do
        results = query(q: "García Hermanos").map(&:legal_name)
        expect(results).to include("García Hermanos")
        expect(results).not_to include("Unrelated")
      end
    end

    context 'when q matches name' do
      it 'returns matching clients' do
        results = query(q: "García López").map(&:name)
        expect(results).to include("García López")
      end
    end

    context 'when q is uppercase' do
      it 'matches case-insensitively' do
        expect(query(q: "GARCÍA").map(&:legal_name)).to include("García Hermanos")
      end
    end

    context 'when q contains SQL wildcard %' do
      it 'treats % as a literal character (no injection)' do
        results = query(q: "%")
        results.each do |client|
          expect(client.user_id).to eq(user.id)
          expect(client.active).to be true
        end
      end
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

    it 'returns only clients in the specified group' do
      results = query(client_group_id: group_a.id).map(&:legal_name)
      expect(results).to contain_exactly("Group A Client")
    end

    it 'returns all active clients when client_group_id is nil' do
      expect(query.count).to eq(3)
    end

    it 'combines q and client_group_id filters' do
      results = query(q: "Group", client_group_id: group_b.id).map(&:legal_name)
      expect(results).to contain_exactly("Group B Client")
    end

    it 'returns empty when client_group_id belongs to another user (safe by composition)' do
      other_user  = create(:user)
      other_group = create(:client_group, user: other_user)
      expect(query(client_group_id: other_group.id).to_a).to be_empty
    end
  end
end
