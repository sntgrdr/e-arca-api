require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_uniqueness_of(:legal_name).case_insensitive }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'tax_condition enum' do
    it 'defines expected values' do
      expect(User.tax_conditions).to include('registered' => 1, 'final_client' => 5)
    end
  end

  describe 'password complexity' do
    it 'is invalid without an uppercase letter' do
      user = build(:user, password: 'secure.pass1', password_confirmation: 'secure.pass1')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'is invalid without a special character (- . _)' do
      user = build(:user, password: 'SecurePass1', password_confirmation: 'SecurePass1')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'is valid with an uppercase letter and special character' do
      user = build(:user, password: 'Secure.pass1', password_confirmation: 'Secure.pass1')
      expect(user).to be_valid
    end
  end

  describe 'dni attribute' do
    it 'stores dni independently from legal_number' do
      user = create(:user, legal_number: '20388864304', dni: '38886430')
      expect(user.reload.dni).to eq('38886430')
      expect(user.reload.legal_number).to eq('20388864304')
    end

    it 'enforces uniqueness on dni' do
      create(:user, legal_number: '20388864304', dni: '38886430')
      duplicate = build(:user, legal_number: '20388864304', dni: '38886430')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'dni_matches_legal_number validation' do
    it 'is invalid when dni does not match digits in legal_number' do
      user = build(:user, legal_number: '20388864304', dni: '99999999')
      expect(user).not_to be_valid
      expect(user.errors[:dni]).to be_present
    end

    it 'is valid when dni matches the middle digits of legal_number' do
      user = build(:user, legal_number: '20388864304', dni: '38886430')
      expect(user).to be_valid
    end

    it 'skips the validation when dni is nil' do
      user = build(:user, legal_number: '20388864304', dni: nil)
      expect(user).to be_valid
    end
  end
end
