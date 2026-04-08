require 'rails_helper'

RSpec.describe Client, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:iva) }
    it { should belong_to(:client_group).optional }
  end

  describe 'validations' do
    subject { build(:client) }

    it { should validate_presence_of(:legal_name) }
    it { should validate_presence_of(:legal_number) }
    it { should validate_presence_of(:tax_condition) }
    it { should validate_uniqueness_of(:legal_name).scoped_to(:user_id) }
    it { should validate_uniqueness_of(:legal_number).scoped_to(:user_id).case_insensitive }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:iva) { create(:iva, user: user) }
    let!(:active_client) { create(:client, user: user, iva: iva, active: true) }
    let!(:inactive_client) { create(:client, user: user, iva: iva, active: false) }

    it '.active returns only active clients' do
      expect(Client.active).to include(active_client)
      expect(Client.active).not_to include(inactive_client)
    end
  end
end
