require 'rails_helper'

RSpec.describe Line, type: :model do
  it { should belong_to(:lineable) }
  it 'has an optional item association (required only for item lines)' do
    expect(build(:adjustment_line, item: nil)).to be_valid
    expect(build(:line, line_type: 'item', item: nil)).not_to be_valid
  end
  it { should belong_to(:user) }
  it { should belong_to(:iva).optional }
  it { should validate_presence_of(:description) }
  it { should validate_presence_of(:quantity) }
  it { should validate_presence_of(:unit_price) }
  it { should validate_presence_of(:final_price) }

  describe 'line_type validations' do
    it 'accepts line_type item' do
      line = build(:line, line_type: 'item')
      expect(line).to be_valid
    end

    it 'accepts line_type adjustment' do
      line = build(:adjustment_line)
      expect(line).to be_valid
    end

    it 'rejects line_type nil' do
      line = build(:line, line_type: nil)
      expect(line).not_to be_valid
    end
  end

  describe 'final_price validation' do
    it 'allows negative final_price for adjustment lines' do
      line = build(:adjustment_line, final_price: -100.0)
      expect(line).to be_valid
    end

    it 'requires positive final_price for item lines' do
      line = build(:line, line_type: 'item', final_price: -1)
      expect(line).not_to be_valid
    end
  end
end
