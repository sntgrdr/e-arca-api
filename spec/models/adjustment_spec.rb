require 'rails_helper'

RSpec.describe Adjustment, type: :model do
  let(:user)   { create(:user) }
  let(:client) { create(:client, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:adjustment_applicables).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:adjustment, user: user, target: client) }

    it { should validate_presence_of(:adjustment_type) }
    it { should validate_presence_of(:calculation_type) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }

    it 'validates percentage discount <= 100' do
      adj = build(:adjustment, user: user, target: client,
                  adjustment_type: 'discount', calculation_type: 'percentage', amount: 101)
      expect(adj).not_to be_valid
      expect(adj.errors[:amount]).to include(match(/100/))
    end

    it 'allows percentage surcharge up to 200' do
      adj = build(:adjustment, user: user, target: client,
                  adjustment_type: 'surcharge', calculation_type: 'percentage', amount: 200)
      expect(adj).to be_valid
    end

    it 'rejects percentage surcharge > 200' do
      adj = build(:adjustment, user: user, target: client,
                  adjustment_type: 'surcharge', calculation_type: 'percentage', amount: 201)
      expect(adj).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_adj)   { create(:adjustment, user: user, target: client, active: true) }
    let!(:inactive_adj) { create(:adjustment, user: user, target: client, active: false) }

    it '.active returns only active adjustments' do
      expect(Adjustment.active).to include(active_adj)
      expect(Adjustment.active).not_to include(inactive_adj)
    end

    it '.valid_on returns adjustments where today is within start/end' do
      in_range  = create(:adjustment, user: user, target: client,
                         start_date: 1.week.ago, end_date: 1.week.from_now)
      expired   = create(:adjustment, user: user, target: client,
                         start_date: 1.month.ago, end_date: 1.day.ago)
      future    = create(:adjustment, user: user, target: client,
                         start_date: 1.day.from_now, end_date: nil)
      open_end  = create(:adjustment, user: user, target: client,
                         start_date: 1.week.ago, end_date: nil)

      result = Adjustment.valid_on(Date.current)
      expect(result).to include(in_range, open_end)
      expect(result).not_to include(expired, future)
    end
  end

  describe 'soft delete' do
    it 'is not returned after discard' do
      adj = create(:adjustment, user: user, target: client)
      adj.discard
      expect(Adjustment.kept).not_to include(adj)
    end
  end
end
