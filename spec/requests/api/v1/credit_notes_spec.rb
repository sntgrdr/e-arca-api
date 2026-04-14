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
end
