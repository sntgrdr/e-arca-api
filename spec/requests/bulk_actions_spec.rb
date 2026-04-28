# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bulk Actions', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva) { create(:iva, user: user) }

  # ---------------------------------------------------------------------------
  # POST /api/v1/clients/bulk_destroy
  # ---------------------------------------------------------------------------
  describe 'POST /api/v1/clients/bulk_destroy' do
    let!(:client1) { create(:client, user: user, iva: iva) }
    let!(:client2) { create(:client, user: user, iva: iva) }
    let!(:final)   { create(:client, user: user, iva: iva, final_client: true) }

    context 'when all clients can be deleted' do
      it 'deletes the clients and returns deleted count' do
        post '/api/v1/clients/bulk_destroy',
             params: { ids: [ client1.id, client2.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(2)
        expect(body['skipped']).to eq(0)
        expect(body['skipped_reasons']).to be_empty
      end
    end

    context 'when a client is the final_client' do
      it 'skips it and returns reason' do
        post '/api/v1/clients/bulk_destroy',
             params: { ids: [ client1.id, final.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(1)
        expect(body['skipped']).to eq(1)
        expect(body['skipped_reasons'].first['reason']).to eq('final_client')
      end
    end

    context 'when a client has invoices' do
      before { create(:client_invoice, user: user, client: client1, sell_point: create(:sell_point, user: user)) }

      it 'skips it with has_invoices reason' do
        post '/api/v1/clients/bulk_destroy',
             params: { ids: [ client1.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(0)
        expect(body['skipped_reasons'].first['reason']).to eq('has_invoices')
        expect(body['skipped_reasons'].first['identifier']).to include(client1.legal_name)
        expect(body['skipped_reasons'].first['identifier']).to include(client1.legal_number)
      end
    end

    context 'with an empty ids array' do
      it 'returns 422' do
        post '/api/v1/clients/bulk_destroy',
             params: { ids: [] },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with more than 500 ids' do
      it 'returns 422' do
        post '/api/v1/clients/bulk_destroy',
             params: { ids: (1..501).to_a },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/clients/bulk_destroy', params: { ids: [ client1.id ] }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with ids belonging to another user' do
      let(:other_user) { create(:user) }
      let!(:other_client) { create(:client, user: other_user, iva: create(:iva, user: other_user)) }

      it 'does not delete and returns deleted: 0' do
        post '/api/v1/clients/bulk_destroy',
             params: { ids: [ other_client.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(0)
        expect(Client.find(other_client.id)).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/items/bulk_destroy
  # ---------------------------------------------------------------------------
  describe 'POST /api/v1/items/bulk_destroy' do
    let!(:item1) { create(:item, user: user, iva: iva) }
    let!(:item2) { create(:item, user: user, iva: iva) }

    context 'when all items can be deleted' do
      it 'deletes and returns deleted count' do
        post '/api/v1/items/bulk_destroy',
             params: { ids: [ item1.id, item2.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(2)
        expect(body['skipped']).to eq(0)
      end
    end

    context 'when an item is referenced in a line' do
      before do
        sell_point = create(:sell_point, user: user)
        client = create(:client, user: user, iva: iva)
        invoice = create(:client_invoice, user: user, client: client, sell_point: sell_point)
        invoice.lines.first.update!(item: item1)
      end

      it 'skips it with referenced_in_line reason' do
        post '/api/v1/items/bulk_destroy',
             params: { ids: [ item1.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(0)
        expect(body['skipped_reasons'].first['reason']).to eq('referenced_in_line')
        expect(body['skipped_reasons'].first['identifier']).to include(item1.name)
        expect(body['skipped_reasons'].first['identifier']).to include(item1.code)
      end
    end

    context 'with empty ids' do
      it 'returns 422' do
        post '/api/v1/items/bulk_destroy',
             params: { ids: [] },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/items/bulk_activate
  # ---------------------------------------------------------------------------
  describe 'PATCH /api/v1/items/bulk_activate' do
    let!(:inactive1) { create(:item, user: user, iva: iva, active: false) }
    let!(:inactive2) { create(:item, user: user, iva: iva, active: false) }

    it 'activates the items and returns updated count' do
      patch '/api/v1/items/bulk_activate',
            params: { ids: [ inactive1.id, inactive2.id ] },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['updated']).to eq(2)
      expect(inactive1.reload.active).to be(true)
      expect(inactive2.reload.active).to be(true)
    end

    it 'returns 422 for empty ids' do
      patch '/api/v1/items/bulk_activate',
            params: { ids: [] },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 when not authenticated' do
      patch '/api/v1/items/bulk_activate', params: { ids: [ inactive1.id ] }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/items/bulk_deactivate
  # ---------------------------------------------------------------------------
  describe 'PATCH /api/v1/items/bulk_deactivate' do
    let!(:active1) { create(:item, user: user, iva: iva, active: true) }
    let!(:active2) { create(:item, user: user, iva: iva, active: true) }

    it 'deactivates the items and returns updated count' do
      patch '/api/v1/items/bulk_deactivate',
            params: { ids: [ active1.id, active2.id ] },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['updated']).to eq(2)
      expect(active1.reload.active).to be(false)
      expect(active2.reload.active).to be(false)
    end

    it 'returns 422 for empty ids' do
      patch '/api/v1/items/bulk_deactivate',
            params: { ids: [] },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/client_invoices/bulk_destroy
  # ---------------------------------------------------------------------------
  describe 'POST /api/v1/client_invoices/bulk_destroy' do
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client)     { create(:client, user: user, iva: iva) }
    let!(:invoice1)  { create(:client_invoice, user: user, client: client, sell_point: sell_point) }
    let!(:invoice2)  { create(:client_invoice, user: user, client: client, sell_point: sell_point) }
    let!(:authorized) { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }

    context 'when all invoices have no CAE' do
      it 'deletes and returns deleted count' do
        post '/api/v1/client_invoices/bulk_destroy',
             params: { ids: [ invoice1.id, invoice2.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(2)
        expect(body['skipped']).to eq(0)
      end
    end

    context 'when an invoice has a CAE' do
      it 'skips it with has_cae reason' do
        post '/api/v1/client_invoices/bulk_destroy',
             params: { ids: [ invoice1.id, authorized.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(1)
        expect(body['skipped']).to eq(1)
        expect(body['skipped_reasons'].first['reason']).to eq('has_cae')
        expect(body['skipped_reasons'].first['identifier']).to eq(authorized.number.to_s)
      end
    end

    context 'with empty ids' do
      it 'returns 422' do
        post '/api/v1/client_invoices/bulk_destroy',
             params: { ids: [] },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/client_invoices/bulk_destroy', params: { ids: [ invoice1.id ] }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/credit_notes/bulk_destroy
  # ---------------------------------------------------------------------------
  describe 'POST /api/v1/credit_notes/bulk_destroy' do
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client)     { create(:client, user: user, iva: iva) }
    let!(:invoice1)  { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }
    let!(:invoice2)  { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }
    let!(:invoice3)  { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }
    let!(:cn1)       { create(:credit_note, client_invoice: invoice1) }
    let!(:cn2)       { create(:credit_note, client_invoice: invoice2) }
    let!(:cn_cae)    { create(:credit_note, :with_cae, client_invoice: invoice3) }

    context 'when all credit notes have no CAE' do
      it 'deletes and returns deleted count' do
        post '/api/v1/credit_notes/bulk_destroy',
             params: { ids: [ cn1.id, cn2.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(2)
        expect(body['skipped']).to eq(0)
      end
    end

    context 'when a credit note has a CAE' do
      it 'skips it with has_cae reason' do
        post '/api/v1/credit_notes/bulk_destroy',
             params: { ids: [ cn1.id, cn_cae.id ] },
             headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['deleted']).to eq(1)
        expect(body['skipped']).to eq(1)
        expect(body['skipped_reasons'].first['reason']).to eq('has_cae')
      end
    end

    context 'with empty ids' do
      it 'returns 422' do
        post '/api/v1/credit_notes/bulk_destroy',
             params: { ids: [] },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        post '/api/v1/credit_notes/bulk_destroy', params: { ids: [ cn1.id ] }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
