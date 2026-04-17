# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::BatchInvoiceProcesses', type: :request do
  let(:user)       { create(:user) }
  let(:headers)    { auth_headers(user) }
  let(:iva)        { create(:iva, user: user) }
  let(:item)       { create(:item, user: user, iva: iva) }
  let(:sell_point) { create(:sell_point, user: user) }

  describe 'GET /api/v1/batch_invoice_processes' do
    let(:sell_point) { create(:sell_point, user: user) }

    before do
      create_list(:batch_invoice_process, 3, user: user, sell_point: sell_point)
    end

    it 'returns 200' do
      get '/api/v1/batch_invoice_processes', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'wraps records under a data key' do
      get '/api/v1/batch_invoice_processes', headers: headers
      body = JSON.parse(response.body)
      expect(body).to have_key('data')
      expect(body['data'].length).to eq(3)
    end

    it 'returns a meta object with pagination fields' do
      get '/api/v1/batch_invoice_processes', headers: headers
      meta = JSON.parse(response.body)['meta']
      expect(meta).to include('count', 'page', 'items', 'pages')
      expect(meta['count']).to eq(3)
    end

    it 'filters by process_type' do
      create(:batch_invoice_process, :final_consumer, user: user, sell_point: sell_point)
      get '/api/v1/batch_invoice_processes', params: { process_type: 'final_consumer' }, headers: headers
      body = JSON.parse(response.body)
      expect(body['meta']['count']).to eq(1)
    end

    context 'without a client_group' do
      before do
        create_list(:batch_invoice_process, 2, user: user, item: item, sell_point: sell_point)
      end

      it 'returns processes with item and sell_point' do
        get '/api/v1/batch_invoice_processes', headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        first = body['data'].first
        expect(first).to include('item', 'sell_point')
        expect(first['item']).to include('id', 'name', 'code')
        expect(first['sell_point']).to include('id', 'number')
      end

      it 'returns client_group as null when not set' do
        get '/api/v1/batch_invoice_processes', headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['data'].first['client_group']).to be_nil
      end

      it 'does not include client_invoices' do
        get '/api/v1/batch_invoice_processes', headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['data'].first).not_to have_key('client_invoices')
      end
    end

    context 'with a client_group' do
      let(:group) { create(:client_group, user: user) }

      before do
        create(:batch_invoice_process, user: user, item: item, sell_point: sell_point, client_group: group)
      end

      it 'returns client_group with id and name' do
        get '/api/v1/batch_invoice_processes', headers: headers, as: :json
        body = JSON.parse(response.body)
        record = body['data'].find { |b| b['client_group'].present? }
        expect(record['client_group']).to include('id' => group.id, 'name' => group.name)
      end
    end
  end

  describe 'GET /api/v1/batch_invoice_processes/:id' do
    let(:batch) do
      create(:batch_invoice_process, user: user, item: item, sell_point: sell_point)
    end

    it 'returns sell_point with id and number' do
      get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body['sell_point']).to include('id' => sell_point.id, 'number' => sell_point.number)
    end

    it 'returns client_group as null when not set' do
      get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body['client_group']).to be_nil
    end

    context 'when batch has a client_group' do
      let(:group) { create(:client_group, user: user) }
      let(:batch_with_group) do
        create(:batch_invoice_process, user: user, item: item, sell_point: sell_point, client_group: group)
      end

      it 'returns client_group with id and name' do
        get "/api/v1/batch_invoice_processes/#{batch_with_group.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_group']).to include('id' => group.id, 'name' => group.name)
      end
    end

    context 'with associated invoices' do
      let(:client) { create(:client, user: user, iva: iva) }

      before do
        create_list(:client_invoice, 3, user: user, client: client, sell_point: sell_point,
                    batch_invoice_process: batch)
      end

      it 'returns client_invoices with slim fields including sell_point_number' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key('client_invoices')
        invoice = body['client_invoices'].first
        expect(invoice.keys).to match_array(%w[id number date client_name client_legal_number
                                               cae afip_authorized_at total_price sell_point_number])
        expect(invoice['sell_point_number']).to eq(sell_point.number)
      end

      it 'returns client_invoices_total and client_invoices_capped' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_invoices_total']).to eq(3)
        expect(body['client_invoices_capped']).to eq(false)
      end

      it 'returns updated_at' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body).to have_key('updated_at')
      end

      it 'sets Cache-Control: no-store' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        expect(response.headers['Cache-Control']).to include('no-store')
      end
    end

    context 'when batch has more than 200 invoices' do
      let(:client) { create(:client, user: user, iva: iva) }

      before do
        create_list(:client_invoice, 201, user: user, client: client, sell_point: sell_point,
                    batch_invoice_process: batch)
      end

      it 'returns at most 200 invoices' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_invoices'].length).to eq(200)
      end

      it 'returns client_invoices_capped: true and correct total' do
        get "/api/v1/batch_invoice_processes/#{batch.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body['client_invoices_capped']).to eq(true)
        expect(body['client_invoices_total']).to eq(201)
      end
    end

    context 'when status is failed' do
      let(:batch_failed) do
        create(:batch_invoice_process, :failed, user: user, item: item, sell_point: sell_point,
               error_details: [ { client_id: 1, error: 'AFIP timeout' } ])
      end

      it 'returns error_details' do
        get "/api/v1/batch_invoice_processes/#{batch_failed.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body).to have_key('error_details')
        expect(body['error_details']).not_to be_empty
      end
    end

    context 'when status is completed' do
      let(:batch_completed) do
        create(:batch_invoice_process, :completed, user: user, item: item, sell_point: sell_point)
      end

      it 'does not return error_details' do
        get "/api/v1/batch_invoice_processes/#{batch_completed.id}", headers: headers, as: :json
        body = JSON.parse(response.body)
        expect(body).not_to have_key('error_details')
      end
    end
  end

  context 'when batch has multiple items' do
    let(:item2) { create(:item, user: user, iva: iva) }
    let(:multi_batch) do
      b = create(:batch_invoice_process, user: user, item: item, sell_point: sell_point)
      BatchInvoiceProcessItem.create!(batch_invoice_process: b, item: item,  position: 0)
      BatchInvoiceProcessItem.create!(batch_invoice_process: b, item: item2, position: 1)
      b
    end

    it 'returns items array in show response' do
      get "/api/v1/batch_invoice_processes/#{multi_batch.id}", headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body['items'].map { |i| i['id'] }).to eq([ item.id, item2.id ])
    end

    it 'returns items array in index response' do
      multi_batch
      get '/api/v1/batch_invoice_processes', headers: headers, as: :json
      body = JSON.parse(response.body)
      batch_body = body['data'].find { |b| b['id'] == multi_batch.id }
      expect(batch_body['items'].size).to eq(2)
    end
  end

  describe 'POST /api/v1/batch_invoice_processes' do
    let(:item2) { create(:item, user: user, iva: iva) }

    context 'with item_ids' do
      it 'creates a batch with multiple items' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               sell_point_id: sell_point.id,
               date: Date.current.iso8601,
               period: '04/2026',
               item_ids: [ item.id, item2.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['items'].map { |i| i['id'] }).to eq([ item.id, item2.id ])
      end
    end

    context 'with client_ids' do
      let(:iva2)   { create(:iva, user: user) }
      let(:client) { create(:client, user: user, iva: iva2) }

      it 'creates a batch scoped to selected clients' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               sell_point_id: sell_point.id,
               date: Date.current.iso8601,
               period: '04/2026',
               item_ids: [ item.id ],
               client_ids: [ client.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:created)
        batch = BatchInvoiceProcess.last
        expect(batch.selected_clients.pluck(:id)).to eq([ client.id ])
      end
    end

    context 'cap enforcement' do
      it 'rejects more than 10 item_ids' do
        items = create_list(:item, 11, user: user, iva: iva)
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               sell_point_id: sell_point.id,
               date: Date.current.iso8601,
               period: '04/2026',
               item_ids: items.map(&:id)
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects more than 100 client_ids' do
        iva2    = create(:iva, user: user)
        clients = create_list(:client, 101, user: user, iva: iva2)
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               sell_point_id: sell_point.id,
               date: Date.current.iso8601,
               period: '04/2026',
               item_ids: [ item.id ],
               client_ids: clients.map(&:id)
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'ownership validation' do
      let(:other_user) { create(:user) }
      let(:other_iva)  { create(:iva, user: other_user) }
      let(:other_item) { create(:item, user: other_user, iva: other_iva) }

      it 'rejects client_ids that do not belong to the selected client_group' do
        other_group           = create(:client_group, user: user)
        iva2                  = create(:iva, user: user)
        client_in_other_group = create(:client, user: user, iva: iva2, client_group: other_group)
        target_group          = create(:client_group, user: user)

        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               sell_point_id: sell_point.id,
               date: Date.current.iso8601,
               period: '04/2026',
               item_ids: [ item.id ],
               client_group_id: target_group.id,
               client_ids: [ client_in_other_group.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects item_ids belonging to another user' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               sell_point_id: sell_point.id,
               date: Date.current.iso8601,
               period: '04/2026',
               item_ids: [ other_item.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  context 'tenant isolation' do
    it_behaves_like 'a user-scoped resource' do
      let(:resource_path) { '/api/v1/batch_invoice_processes' }
      let(:resource) do
        iva_a   = create(:iva, user: user_a)
        item_a  = create(:item, user: user_a, iva: iva_a)
        sp_a    = create(:sell_point, user: user_a)
        create(:batch_invoice_process, user: user_a, item: item_a, sell_point: sp_a)
      end
      let(:resource_list) do
        iva_a   = create(:iva, user: user_a)
        item_a  = create(:item, user: user_a, iva: iva_a)
        sp_a    = create(:sell_point, user: user_a)
        create_list(:batch_invoice_process, 2, user: user_a, item: item_a, sell_point: sp_a)
      end
    end
  end

  # ── Final Consumer batch ────────────────────────────────────────────────────

  describe 'POST /api/v1/batch_invoice_processes (final_consumer)' do
    context 'with valid params' do
      it 'creates the batch and returns 201' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: sell_point.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      5,
               item_ids:      [ item.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['process_type']).to eq('final_consumer')
        expect(body['quantity']).to eq(5)
      end

      it 'defaults invoice_type to C for self_employed user' do
        self_employed_user    = create(:user, tax_condition: :self_employed)
        self_employed_headers = auth_headers(self_employed_user)
        self_employed_sp      = create(:sell_point, user: self_employed_user)
        self_employed_iva     = create(:iva, user: self_employed_user)
        self_employed_item    = create(:item, user: self_employed_user, iva: self_employed_iva)

        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: self_employed_sp.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      3,
               item_ids:      [ self_employed_item.id ]
             } },
             headers: self_employed_headers, as: :json

        expect(JSON.parse(response.body)['invoice_type']).to eq('C')
      end

      it 'accepts an explicit invoice_type' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: sell_point.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      3,
               invoice_type:  'B',
               item_ids:      [ item.id ]
             } },
             headers: headers, as: :json

        expect(JSON.parse(response.body)['invoice_type']).to eq('B')
      end
    end

    context 'validations' do
      it 'rejects quantity of 0' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: sell_point.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      0,
               item_ids:      [ item.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects quantity above 200' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: sell_point.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      201,
               item_ids:      [ item.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects empty item_ids' do
        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: sell_point.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      5,
               item_ids:      []
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects item_ids belonging to another user' do
        other_user = create(:user)
        other_iva  = create(:iva, user: other_user)
        other_item = create(:item, user: other_user, iva: other_iva)

        post '/api/v1/batch_invoice_processes',
             params: { batch_invoice_process: {
               process_type:  'final_consumer',
               sell_point_id: sell_point.id,
               date:          Date.current.iso8601,
               period:        '04/2026',
               quantity:      5,
               item_ids:      [ other_item.id ]
             } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'BatchInvoiceProcessors::FinalConsumer (job execution)' do
    let(:final_client) do
      create(:client, user: user, legal_name: 'Consumidor Final',
             legal_number: '0', tax_condition: :final_client,
             final_client: true, active: true, iva_id: nil)
    end

    let(:batch) do
      b = create(:batch_invoice_process, :final_consumer,
                 user: user, sell_point: sell_point,
                 date: Date.current, period: Date.current,
                 quantity: 3, invoice_type: 'C')
      create(:batch_invoice_process_item, batch_invoice_process: b, item: item, position: 0)
      b
    end

    before { final_client }

    it 'creates quantity invoices for the final consumer client' do
      expect {
        BatchInvoiceProcessors::FinalConsumer.new(batch).run
      }.to change { ClientInvoice.where(client: final_client).count }.by(3)
    end

    it 'marks the batch as completed' do
      BatchInvoiceProcessors::FinalConsumer.new(batch).run
      expect(batch.reload.status).to eq('completed')
    end

    it 'sets total_invoices to quantity' do
      BatchInvoiceProcessors::FinalConsumer.new(batch).run
      expect(batch.reload.total_invoices).to eq(3)
    end

    it 'raises MissingFinalConsumerClient when no final client exists' do
      final_client.destroy!
      expect {
        BatchInvoiceProcessors::FinalConsumer.new(batch).run
      }.to raise_error(BatchInvoiceProcessors::FinalConsumer::MissingFinalConsumerClient)
    end

    context 'idempotency on retry' do
      it 'skips already-processed invoices and creates only the remaining ones' do
        batch.update!(processed_invoices: 2)
        expect {
          BatchInvoiceProcessors::FinalConsumer.new(batch).run
        }.to change { ClientInvoice.where(client: final_client).count }.by(1)
      end
    end
  end
end
