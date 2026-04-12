require 'rails_helper'

RSpec.describe Client, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:iva).optional }
    it { should belong_to(:client_group).optional }
  end

  describe 'validations' do
    subject { build(:client) }

    it { should validate_presence_of(:legal_name) }
    it { should validate_presence_of(:legal_number) }
    it { should validate_presence_of(:tax_condition) }
    it { should validate_uniqueness_of(:legal_name).scoped_to(:user_id) }
    it 'enforces uniqueness of legal_number within the same user' do
      existing = create(:client)
      duplicate = build(:client, user: existing.user, legal_number: existing.legal_number)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:legal_number]).to be_present
    end

    it 'allows the same legal_number for different users' do
      existing = create(:client)
      other_user = create(:user)
      other = build(:client, user: other_user, legal_number: existing.legal_number)
      expect(other).to be_valid
    end
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
