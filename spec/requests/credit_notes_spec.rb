require 'rails_helper'

RSpec.describe 'Api::V1::CreditNotes', type: :request do
  let(:user)       { create(:user) }
  let(:headers)    { auth_headers(user) }
  let(:iva)        { create(:iva, user: user) }
  let(:client)     { create(:client, user: user, iva: iva) }
  let(:sell_point) { create(:sell_point, user: user) }
  let(:item_a)     { create(:item, user: user, iva: iva) }

  let(:invoice) do
    inv = ClientInvoice.new(
      user: user, client: client, sell_point: sell_point,
      number: '1', date: Date.current, period: Date.current,
      invoice_type: 'C', total_price: 50_000,
      afip_status: :authorized, cae: '12345678901234',
      cae_expiration: 10.days.from_now.to_date,
      afip_invoice_number: '1', afip_result: 'A',
      afip_authorized_at: Time.current
    )
    inv.lines.build(user: user, item: item_a, iva: iva,
                    description: 'Servicio', quantity: 1,
                    unit_price: 50_000, final_price: 50_000)
    inv.save!
    inv
  end

  let(:credit_note) do
    cn = CreditNote.new(
      user: user, client: client, sell_point: sell_point,
      client_invoice: invoice, number: '1', date: Date.current,
      period: invoice.period, invoice_type: invoice.invoice_type,
      total_price: 10_000, afip_status: :draft
    )
    cn.lines.build(user: user, item: item_a, iva: iva,
                   description: 'Servicio', quantity: 1,
                   unit_price: 10_000, final_price: 10_000)
    cn.save!
    cn
  end

  # ── Index ─────────────────────────────────────────────────────────────────

  describe 'GET /api/v1/credit_notes' do
    before { credit_note }

    it 'returns 200' do
      get '/api/v1/credit_notes', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'wraps records under a data key' do
      get '/api/v1/credit_notes', headers: headers
      body = JSON.parse(response.body)
      expect(body).to have_key('data')
      expect(body['data'].length).to eq(1)
    end

    it 'returns a meta object with pagination fields' do
      get '/api/v1/credit_notes', headers: headers
      meta = JSON.parse(response.body)['meta']
      expect(meta).to include('count', 'page', 'items', 'pages')
      expect(meta['count']).to eq(1)
    end

    it 'includes expected fields in each record' do
      get '/api/v1/credit_notes', headers: headers
      record = JSON.parse(response.body)['data'].first
      expect(record).to include('id', 'number', 'date', 'total_price',
                                'invoice_type', 'can_edit', 'can_send_to_arca',
                                'remaining_balance')
    end

    context 'with multiple pages' do
      before do
        # 20 more credit notes → 21 total, page 1 has 20
        20.times do |i|
          cn = CreditNote.new(
            user: user, client: client, sell_point: sell_point,
            client_invoice: invoice, number: (i + 2).to_s, date: Date.current,
            period: invoice.period, invoice_type: invoice.invoice_type,
            total_price: 500, afip_status: :draft
          )
          cn.lines.build(user: user, item: item_a, iva: iva,
                         description: 'Servicio', quantity: 1,
                         unit_price: 500, final_price: 500)
          cn.save!
        end
      end

      it 'respects the page param' do
        get '/api/v1/credit_notes', params: { page: 2 }, headers: headers
        body = JSON.parse(response.body)
        expect(body['meta']['page']).to eq(2)
        # 21 total records, 20 per page → page 2 has exactly 1 record
        expect(body['data'].length).to eq(1)
      end
    end

    it 'returns 404 for an out-of-range page' do
      get '/api/v1/credit_notes', params: { page: 9999 }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 when unauthenticated' do
      get '/api/v1/credit_notes'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── Show ──────────────────────────────────────────────────────────────────

  describe 'GET /api/v1/credit_notes/:id' do
    it 'returns 200 with correct shape' do
      get "/api/v1/credit_notes/#{credit_note.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include('id', 'number', 'invoice_type', 'total_price',
                              'can_edit', 'can_send_to_arca', 'lines', 'client', 'sell_point')
    end

    it 'returns can_edit: true when no CAE' do
      get "/api/v1/credit_notes/#{credit_note.id}", headers: headers
      expect(JSON.parse(response.body)['can_edit']).to eq(true)
    end

    it 'returns can_send_to_arca: true when not yet authorized' do
      get "/api/v1/credit_notes/#{credit_note.id}", headers: headers
      expect(JSON.parse(response.body)['can_send_to_arca']).to eq(true)
    end

    context 'when credit note has a CAE' do
      before do
        credit_note.update_columns(
          cae: '98765432109876', cae_expiration: 10.days.from_now.to_date,
          afip_status: 'authorized', afip_authorized_at: Time.current
        )
      end

      it 'returns can_edit: false' do
        get "/api/v1/credit_notes/#{credit_note.id}", headers: headers
        expect(JSON.parse(response.body)['can_edit']).to eq(false)
      end

      it 'returns can_send_to_arca: false' do
        get "/api/v1/credit_notes/#{credit_note.id}", headers: headers
        expect(JSON.parse(response.body)['can_send_to_arca']).to eq(false)
      end
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/credit_notes/999999', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── Next number ───────────────────────────────────────────────────────────

  describe 'GET /api/v1/credit_notes/next_number' do
    it 'returns the next number as string' do
      get '/api/v1/credit_notes/next_number',
          params: { sell_point_id: sell_point.id, invoice_type: 'C' },
          headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['number']).to eq('1')
    end
  end

  # ── Create from invoice ───────────────────────────────────────────────────

  describe 'GET /api/v1/credit_notes/create_from_invoice' do
    context 'when invoice has remaining balance' do
      it 'returns 200 with remaining_balance in the response' do
        get '/api/v1/credit_notes/create_from_invoice',
            params: { client_invoice_id: invoice.id },
            headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['remaining_balance']).to eq(50_000.0)
      end

      it 'returns remaining_balance equal to invoice total when no prior CNs' do
        get '/api/v1/credit_notes/create_from_invoice',
            params: { client_invoice_id: invoice.id },
            headers: headers

        body = JSON.parse(response.body)
        expect(body['remaining_balance']).to eq(invoice.total_price.to_f)
      end

      context 'when a prior credit note of 25,000 exists' do
        before do
          cn = CreditNote.new(
            user: user, client: client, sell_point: sell_point,
            client_invoice: invoice, number: '1', date: Date.current,
            period: invoice.period, invoice_type: invoice.invoice_type,
            total_price: 25_000, afip_status: :draft
          )
          cn.lines.build(user: user, item: item_a, iva: iva,
                         description: 'Servicio', quantity: 1,
                         unit_price: 25_000, final_price: 25_000)
          cn.save!
        end

        it 'returns remaining_balance reflecting the prior credit note' do
          get '/api/v1/credit_notes/create_from_invoice',
              params: { client_invoice_id: invoice.id },
              headers: headers

          body = JSON.parse(response.body)
          expect(body['remaining_balance']).to eq(25_000.0)
        end
      end
    end

    context 'when invoice is fully credited' do
      before do
        cn = CreditNote.new(
          user: user, client: client, sell_point: sell_point,
          client_invoice: invoice, number: '1', date: Date.current,
          period: invoice.period, invoice_type: invoice.invoice_type,
          total_price: 50_000, afip_status: :draft
        )
        cn.lines.build(user: user, item: item_a, iva: iva,
                       description: 'Servicio', quantity: 1,
                       unit_price: 50_000, final_price: 50_000)
        cn.save!
      end

      it 'returns 422' do
        get '/api/v1/credit_notes/create_from_invoice',
            params: { client_invoice_id: invoice.id },
            headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns a meaningful error message' do
        get '/api/v1/credit_notes/create_from_invoice',
            params: { client_invoice_id: invoice.id },
            headers: headers

        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
      end
    end
  end

  # ── Create ────────────────────────────────────────────────────────────────

  describe 'POST /api/v1/credit_notes' do
    let(:valid_params) do
      {
        credit_note: {
          number:           '1',
          date:             Date.current.to_s,
          period:           invoice.period.to_s,
          invoice_type:     invoice.invoice_type,
          total_price:      10_000,
          sell_point_id:    sell_point.id,
          client_id:        client.id,
          client_invoice_id: invoice.id,
          lines_attributes: [
            {
              item_id:     item_a.id,
              description: 'Servicio',
              quantity:    1,
              unit_price:  10_000,
              final_price: 10_000,
              iva_id:      iva.id
            }
          ]
        }
      }
    end

    it 'creates the credit note and returns 201' do
      post '/api/v1/credit_notes', params: valid_params, headers: headers, as: :json
      expect(response).to have_http_status(:created)
    end

    it 'returns the created credit note with lines' do
      post '/api/v1/credit_notes', params: valid_params, headers: headers, as: :json
      body = JSON.parse(response.body)
      expect(body['lines'].length).to eq(1)
      expect(body['id']).to be_present
    end

    context 'when total exceeds invoice remaining balance' do
      it 'returns 422 with validation error' do
        params = valid_params.deep_merge(
          credit_note: { total_price: 999_999 }
        )
        post '/api/v1/credit_notes', params: params, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── Update ────────────────────────────────────────────────────────────────

  describe 'PUT /api/v1/credit_notes/:id' do
    let(:update_params) do
      {
        credit_note: {
          date: Date.current.to_s,
          lines_attributes: [
            {
              id:          credit_note.lines.first.id,
              description: 'Servicio actualizado',
              quantity:    1,
              unit_price:  10_000,
              final_price: 10_000,
              iva_id:      iva.id
            }
          ]
        }
      }
    end

    it 'returns 200 and updates the credit note' do
      put "/api/v1/credit_notes/#{credit_note.id}",
          params: update_params, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
    end

    context 'when credit note is already authorized (has CAE)' do
      before do
        credit_note.update_columns(
          cae: '98765432109876', cae_expiration: 10.days.from_now.to_date,
          afip_status: 'authorized', afip_authorized_at: Time.current
        )
      end

      it 'returns 422 with cannot_edit error code' do
        put "/api/v1/credit_notes/#{credit_note.id}",
            params: update_params, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('cannot_edit')
      end
    end

    context 'when updated total exceeds invoice remaining balance' do
      before do
        # Create a second credit note using most of the remaining balance
        cn2 = CreditNote.new(
          user: user, client: client, sell_point: sell_point,
          client_invoice: invoice, number: '2', date: Date.current,
          period: invoice.period, invoice_type: invoice.invoice_type,
          total_price: 39_000, afip_status: :draft
        )
        cn2.lines.build(user: user, item: item_a, iva: iva,
                        description: 'Segunda NC', quantity: 1,
                        unit_price: 39_000, final_price: 39_000)
        cn2.save!
      end

      it 'returns 422 when total would exceed remaining balance' do
        # credit_note has 10_000, cn2 has 39_000 → remaining for cn1 is 11_000
        # trying to update to 20_000 should fail
        params = {
          credit_note: {
            total_price: 20_000,
            lines_attributes: [
              {
                id:          credit_note.lines.first.id,
                description: 'Servicio',
                quantity:    1,
                unit_price:  20_000,
                final_price: 20_000,
                iva_id:      iva.id
              }
            ]
          }
        }
        put "/api/v1/credit_notes/#{credit_note.id}",
            params: params, headers: headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── Destroy ───────────────────────────────────────────────────────────────

  describe 'DELETE /api/v1/credit_notes/:id' do
    it 'soft-deletes the credit note and returns 204' do
      delete "/api/v1/credit_notes/#{credit_note.id}", headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it 'makes the credit note inaccessible after deletion' do
      delete "/api/v1/credit_notes/#{credit_note.id}", headers: headers
      get "/api/v1/credit_notes/#{credit_note.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    context 'when credit note is authorized (has CAE)' do
      before do
        credit_note.update_columns(
          cae: '98765432109876', cae_expiration: 10.days.from_now.to_date,
          afip_status: 'authorized', afip_authorized_at: Time.current
        )
      end

      it 'returns 422 with cannot_delete error code' do
        delete "/api/v1/credit_notes/#{credit_note.id}", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body.dig('error', 'code')).to eq('cannot_delete')
      end
    end
  end

  # ── Download PDF ──────────────────────────────────────────────────────────

  describe 'GET /api/v1/credit_notes/:id/download_pdf' do
    context 'when credit note has no CAE' do
      it 'returns 422' do
        get "/api/v1/credit_notes/#{credit_note.id}/download_pdf", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when credit note has a CAE' do
      before do
        credit_note.update_columns(
          cae: '98765432109876', cae_expiration: 10.days.from_now.to_date,
          afip_status: 'authorized', afip_authorized_at: Time.current
        )
      end

      it 'returns a PDF binary' do
        get "/api/v1/credit_notes/#{credit_note.id}/download_pdf", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/pdf')
        expect(response.body[0..3]).to eq('%PDF')
      end

      it 'sets a filename with nota_credito prefix' do
        get "/api/v1/credit_notes/#{credit_note.id}/download_pdf", headers: headers
        expect(response.headers['Content-Disposition']).to include('nota_credito_')
      end
    end
  end
end
