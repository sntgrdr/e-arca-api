require 'rails_helper'

RSpec.describe Item, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:iva) }
  end

  describe 'validations' do
    subject { build(:item) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
    it 'validates uniqueness of code per user' do
      existing = create(:item)
      dup = build(:item, code: existing.code, user: existing.user, iva: existing.iva)
      expect(dup).not_to be_valid
    end

    it 'allows same code for different users' do
      item1 = create(:item)
      user2 = create(:user)
      iva2 = create(:iva, user: user2)
      item2 = build(:item, code: item1.code, user: user2, iva: iva2)
      expect(item2).to be_valid
    end
  end

  describe 'callbacks' do
    it 'upcases code before validation' do
      item = build(:item, code: 'abc')
      item.valid?
      expect(item.code).to eq('ABC')
    end

    it 'subtracts IVA from price before save' do
      iva = create(:iva, percentage: 21.0)
      item = create(:item, iva: iva, price: 121.0)
      expect(item.price).to be_within(0.01).of(100.0)
    end
  end
end
