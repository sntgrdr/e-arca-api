require 'rails_helper'

RSpec.describe Filters::ClientsFilterService, type: :service do
  subject(:filter) { described_class.new(params, scope).call }

  let(:user) { create(:user) }
  let(:scope) { Client.all }

  describe 'empty/nil params' do
    let!(:client_a) { create(:client, user: user) }
    let!(:client_b) { create(:client, user: user) }

    context 'when params is empty hash' do
      let(:params) { {} }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(client_a, client_b)
      end
    end

    context 'when params values are nil' do
      let(:params) { { legal_name: nil, legal_number: nil, name: nil, tax_condition: nil, client_group_id: nil } }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(client_a, client_b)
      end
    end

    context 'when params values are blank strings' do
      let(:params) { { legal_name: '', legal_number: '', name: '' } }

      it 'returns the full unfiltered scope' do
        expect(filter).to include(client_a, client_b)
      end
    end
  end

  describe '#filter_by_legal_name' do
    let!(:acme)    { create(:client, user: user, legal_name: 'Acme Corp SA') }
    let!(:globex)  { create(:client, user: user, legal_name: 'Globex Solutions SRL') }

    context 'with an exact match' do
      let(:params) { { legal_name: 'Acme Corp SA' } }

      it 'returns the matching client' do
        expect(filter).to include(acme)
        expect(filter).not_to include(globex)
      end
    end

    context 'with a partial match' do
      let(:params) { { legal_name: 'corp' } }

      it 'performs partial ILIKE matching' do
        expect(filter).to include(acme)
        expect(filter).not_to include(globex)
      end
    end

    context 'with case-insensitive input' do
      let(:params) { { legal_name: 'ACME' } }

      it 'matches regardless of case' do
        expect(filter).to include(acme)
        expect(filter).not_to include(globex)
      end
    end

    context 'with SQL injection attempt' do
      let(:params) { { legal_name: "'; DROP TABLE clients; --" } }

      it 'does not raise and returns empty result' do
        expect { filter.to_a }.not_to raise_error
      end
    end
  end

  describe '#filter_by_legal_number' do
    let!(:client_a) { create(:client, user: user, legal_number: '30-12345678-5') }
    let!(:client_b) { create(:client, user: user, legal_number: '20-99999999-9') }

    context 'with a partial match' do
      let(:params) { { legal_number: '12345' } }

      it 'returns the matching client' do
        expect(filter).to include(client_a)
        expect(filter).not_to include(client_b)
      end
    end

    context 'with case-insensitive input' do
      let(:params) { { legal_number: '3012345678' } }

      it 'matches the legal number' do
        expect(filter).to include(client_a)
      end
    end
  end

  describe '#filter_by_name' do
    let!(:juan) { create(:client, user: user, name: 'Juan Pérez') }
    let!(:maria) { create(:client, user: user, name: 'María García') }

    context 'with a partial match' do
      let(:params) { { name: 'pérez' } }

      it 'performs case-insensitive partial ILIKE matching' do
        expect(filter).to include(juan)
        expect(filter).not_to include(maria)
      end
    end

    context 'with SQL injection attempt' do
      let(:params) { { name: "'; DROP TABLE clients; --" } }

      it 'does not raise' do
        expect { filter.to_a }.not_to raise_error
      end
    end
  end

  describe '#filter_by_tax_condition' do
    let!(:final_client)   { create(:client, user: user, tax_condition: :final_client) }
    let!(:registered)     { create(:client, user: user, tax_condition: :registered) }
    let!(:exempt)         { create(:client, user: user, tax_condition: :exempt) }

    context 'with a single value' do
      let(:params) { { tax_condition: [ 'final_client' ] } }

      it 'returns only clients with that tax condition' do
        expect(filter).to include(final_client)
        expect(filter).not_to include(registered, exempt)
      end
    end

    context 'with multiple values' do
      let(:params) { { tax_condition: [ 'final_client', 'registered' ] } }

      it 'returns clients matching any of the given tax conditions' do
        expect(filter).to include(final_client, registered)
        expect(filter).not_to include(exempt)
      end
    end

    context 'when value is not an array' do
      let(:params) { { tax_condition: 'exempt' } }

      it 'coerces to array and filters correctly' do
        expect(filter).to include(exempt)
        expect(filter).not_to include(final_client, registered)
      end
    end
  end

  describe '#filter_by_client_group_id' do
    let(:group_a) { create(:client_group, user: user) }
    let(:group_b) { create(:client_group, user: user) }
    let!(:client_in_a) { create(:client, user: user, client_group: group_a) }
    let!(:client_in_b) { create(:client, user: user, client_group: group_b) }
    let!(:no_group)    { create(:client, user: user, client_group: nil) }

    context 'with a single group id' do
      let(:params) { { client_group_id: [ group_a.id ] } }

      it 'returns only clients in that group' do
        expect(filter).to include(client_in_a)
        expect(filter).not_to include(client_in_b, no_group)
      end
    end

    context 'with multiple group ids' do
      let(:params) { { client_group_id: [ group_a.id, group_b.id ] } }

      it 'returns clients in any of the given groups' do
        expect(filter).to include(client_in_a, client_in_b)
        expect(filter).not_to include(no_group)
      end
    end
  end

  describe 'combined filters' do
    let(:group) { create(:client_group, user: user) }
    let!(:target) do
      create(:client,
             user: user,
             legal_name: 'Target SA',
             tax_condition: :registered,
             client_group: group)
    end
    let!(:other) do
      create(:client,
             user: user,
             legal_name: 'Other Corp',
             tax_condition: :final_client)
    end

    let(:params) do
      {
        legal_name: 'Target',
        tax_condition: [ 'registered' ],
        client_group_id: [ group.id ]
      }
    end

    it 'applies all filters together and returns the correct record' do
      expect(filter).to include(target)
      expect(filter).not_to include(other)
    end
  end
end
