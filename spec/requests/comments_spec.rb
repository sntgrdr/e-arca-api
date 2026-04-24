# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comments', type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:iva)     { create(:iva, user: user) }

  # ---------------------------------------------------------------------------
  # Client Invoice comments
  # ---------------------------------------------------------------------------
  describe 'client_invoices/:id/comments' do
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client)     { create(:client, user: user, iva: iva) }
    let!(:invoice)   { create(:client_invoice, user: user, client: client, sell_point: sell_point) }

    describe 'GET /api/v1/client_invoices/:id/comments' do
      before { create(:comment, commentable: invoice, user: user, body: 'First note') }

      it 'returns comments for the invoice' do
        get "/api/v1/client_invoices/#{invoice.id}/comments", headers: headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.length).to eq(1)
        expect(body.first['body']).to eq('First note')
      end

      it 'returns 401 without auth' do
        get "/api/v1/client_invoices/#{invoice.id}/comments"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'POST /api/v1/client_invoices/:id/comments' do
      it 'creates a comment' do
        post "/api/v1/client_invoices/#{invoice.id}/comments",
             params: { comment: { body: 'Needs review' } },
             headers: headers, as: :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['body']).to eq('Needs review')
        expect(body['commentable_id']).to eq(invoice.id)
        expect(body['commentable_type']).to eq('Invoice')
      end

      it 'returns 422 with blank body' do
        post "/api/v1/client_invoices/#{invoice.id}/comments",
             params: { comment: { body: '' } },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 404 for another user\'s invoice' do
        other_invoice = create(:client_invoice, user: create(:user),
                                                client: create(:client, user: create(:user), iva: create(:iva, user: create(:user))),
                                                sell_point: create(:sell_point, user: create(:user)))
        post "/api/v1/client_invoices/#{other_invoice.id}/comments",
             params: { comment: { body: 'Hack' } },
             headers: headers, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'DELETE /api/v1/client_invoices/:invoice_id/comments/:id' do
      let!(:comment) { create(:comment, commentable: invoice, user: user) }

      it 'deletes the comment' do
        delete "/api/v1/client_invoices/#{invoice.id}/comments/#{comment.id}", headers: headers

        expect(response).to have_http_status(:no_content)
        expect(Comment.find_by(id: comment.id)).to be_nil
      end

      it 'returns 403 when trying to delete another user\'s comment' do
        other_comment = create(:comment, commentable: invoice, user: create(:user))

        delete "/api/v1/client_invoices/#{invoice.id}/comments/#{other_comment.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Credit Note comments
  # ---------------------------------------------------------------------------
  describe 'credit_notes/:id/comments' do
    let(:sell_point) { create(:sell_point, user: user) }
    let(:client)     { create(:client, user: user, iva: iva) }
    let!(:invoice)   { create(:client_invoice, :with_cae, user: user, client: client, sell_point: sell_point) }
    let!(:cn)        { create(:credit_note, client_invoice: invoice) }

    describe 'POST /api/v1/credit_notes/:id/comments' do
      it 'creates a comment on the credit note' do
        post "/api/v1/credit_notes/#{cn.id}/comments",
             params: { comment: { body: 'Credited due to return' } },
             headers: headers, as: :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['commentable_type']).to eq('Invoice')
        expect(body['commentable_id']).to eq(cn.id)
      end
    end

    describe 'DELETE /api/v1/credit_notes/:credit_note_id/comments/:id' do
      let!(:comment) { create(:comment, commentable: cn, user: user) }

      it 'deletes the comment' do
        delete "/api/v1/credit_notes/#{cn.id}/comments/#{comment.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Client comments
  # ---------------------------------------------------------------------------
  describe 'clients/:id/comments' do
    let!(:client) { create(:client, user: user, iva: iva) }

    describe 'POST /api/v1/clients/:id/comments' do
      it 'creates a comment on the client' do
        post "/api/v1/clients/#{client.id}/comments",
             params: { comment: { body: 'VIP client' } },
             headers: headers, as: :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['commentable_type']).to eq('Client')
        expect(body['body']).to eq('VIP client')
      end
    end

    describe 'GET /api/v1/clients/:id/comments' do
      before { create_list(:comment, 2, commentable: client, user: user) }

      it 'returns all comments for the client' do
        get "/api/v1/clients/#{client.id}/comments", headers: headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).length).to eq(2)
      end
    end

    describe 'DELETE /api/v1/clients/:client_id/comments/:id' do
      let!(:comment) { create(:comment, commentable: client, user: user) }

      it 'deletes the comment' do
        delete "/api/v1/clients/#{client.id}/comments/#{comment.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
