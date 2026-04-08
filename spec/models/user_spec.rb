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
end
