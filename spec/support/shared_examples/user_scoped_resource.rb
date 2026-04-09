# frozen_string_literal: true

# Shared examples that verify multi-tenancy enforcement for user-scoped resources.
#
# Usage:
#   it_behaves_like 'a user-scoped resource' do
#     let(:resource_path) { '/api/v1/clients' }
#     let(:resource) { create(:client, user: user_a, iva: iva_a) }
#     let(:resource_list) { create_list(:client, 2, user: user_a, iva: iva_a) }
#   end
#
# The consuming context must define:
#   - resource_path: base URL for the resource (e.g., "/api/v1/clients")
#   - resource:      a single instance owned by user_a
#   - resource_list: a list of instances owned by user_a (used for index isolation)

RSpec.shared_examples 'a user-scoped resource' do
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:headers_b) { auth_headers(user_b) }

  describe 'cross-user show' do
    it 'returns 404 when User B tries to GET User A resource' do
      resource # ensure created
      get "#{resource_path}/#{resource.id}", headers: headers_b, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'cross-user update' do
    it 'returns 404 when User B tries to PATCH User A resource' do
      resource # ensure created
      patch "#{resource_path}/#{resource.id}", params: {}, headers: headers_b, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'cross-user delete' do
    it 'returns 404 when User B tries to DELETE User A resource' do
      resource # ensure created
      delete "#{resource_path}/#{resource.id}", headers: headers_b, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'cross-user index isolation' do
    it 'does not include User A resources in User B index' do
      resource_list # ensure created
      get resource_path, headers: headers_b, as: :json
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      # Handle both paginated (hash with "data" key) and plain array responses
      records = body.is_a?(Array) ? body : (body['data'] || [])
      resource_ids = records.map { |r| r['id'] }
      owner_ids = resource_list.map(&:id)

      expect(resource_ids & owner_ids).to be_empty,
        "User B's index should not contain any of User A's resource IDs, " \
        "but found: #{resource_ids & owner_ids}"
    end
  end
end

# Shared examples for member actions that should be scoped per user.
# Use for custom member routes like send_to_arca, download_pdf, generate_pdfs.
#
# Usage:
#   it_behaves_like 'a user-scoped member action' do
#     let(:resource_path) { '/api/v1/client_invoices' }
#     let(:resource) { create(:client_invoice, user: user_a, ...) }
#     let(:action_name) { 'send_to_arca' }
#     let(:http_method) { :post }
#   end

RSpec.shared_examples 'a user-scoped member action' do
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:headers_b) { auth_headers(user_b) }

  it 'returns 404 when User B tries to access User A resource via member action' do
    resource # ensure created
    send(http_method, "#{resource_path}/#{resource.id}/#{action_name}", headers: headers_b, as: :json)
    expect(response).to have_http_status(:not_found)
  end
end
