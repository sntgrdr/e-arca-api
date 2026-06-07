require 'rails_helper'

RSpec.describe Adjustment, type: :model do
  let(:user)   { create(:user) }
  let(:client) { create(:client, user: user) }
  let(:iva)    { create(:iva, user: user, percentage: 21.0) }

  describe 'end_date_after_start_date validation' do
    it 'is valid when end_date is after start_date' do
      adj = build(:adjustment, user: user, target: client,
                  start_date: Date.current, end_date: 1.week.from_now)
      expect(adj).to be_valid
    end

    it 'is valid when end_date is nil' do
      adj = build(:adjustment, user: user, target: client,
                  start_date: Date.current, end_date: nil)
      expect(adj).to be_valid
    end

    it 'is invalid when end_date is before start_date' do
      adj = build(:adjustment, user: user, target: client,
                  start_date: Date.current, end_date: 1.day.ago)
      expect(adj).not_to be_valid
      expect(adj.errors[:end_date]).to include("no puede ser anterior a la fecha de inicio")
    end
  end

  describe 'iva_id presence for fixed adjustments' do
    it 'is valid for percentage adjustments without iva_id' do
      adj = build(:adjustment, user: user, target: client,
                  calculation_type: 'percentage', amount: 10.0)
      expect(adj).to be_valid
    end

    it 'is invalid for fixed adjustments without iva_id' do
      adj = build(:adjustment, user: user, target: client,
                  calculation_type: 'fixed', amount: 100.0, iva_id: nil)
      expect(adj).not_to be_valid
      expect(adj.errors[:iva_id]).to be_present
    end

    it 'is valid for fixed adjustments with iva_id' do
      adj = build(:adjustment, user: user, target: client,
                  calculation_type: 'fixed', amount: 100.0, iva_id: iva.id)
      expect(adj).to be_valid
    end
  end
end
