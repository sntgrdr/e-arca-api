require 'rails_helper'

RSpec.describe ProvisionDefaultUserResourcesJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    it 'creates a default IVA for the user' do
      expect {
        described_class.perform_now(user.id)
      }.to change { Iva.where(user: user, percentage: 21).count }.by(1)
    end

    it 'creates a Consumidor Final client for the user' do
      expect {
        described_class.perform_now(user.id)
      }.to change { Client.where(user: user, final_client: true).count }.by(1)
    end

    it 'creates the client with correct attributes' do
      described_class.perform_now(user.id)
      client = Client.find_by(user: user, final_client: true)
      expect(client.legal_name).to eq('Consumidor Final')
      expect(client.legal_number).to eq('11111111111')
      expect(client.iva_id).to be_nil
      expect(client.active).to eq(true)
      expect(client.tax_condition).to eq('final_client')
    end

    it 'is idempotent — running twice does not create duplicates' do
      described_class.perform_now(user.id)
      expect {
        described_class.perform_now(user.id)
      }.not_to change { Client.where(user: user, final_client: true).count }
    end

    it 'uses find_or_create for IVA — no duplicate IVAs' do
      create(:iva, user: user, percentage: 21, name: 'IVA 21%')
      expect {
        described_class.perform_now(user.id)
      }.not_to change { Iva.where(user: user, percentage: 21).count }
    end
  end

  describe 'enqueued on user registration' do
    it 'enqueues the job after user creation' do
      expect {
        create(:user)
      }.to have_enqueued_job(described_class)
    end
  end
end
