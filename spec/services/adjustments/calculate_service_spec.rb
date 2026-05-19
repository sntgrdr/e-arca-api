require 'rails_helper'

RSpec.describe Adjustments::CalculateService, type: :service do
  def call(unit_price:, discount: nil, surcharge: nil)
    described_class.new(
      unit_price: unit_price,
      discount:   discount,
      surcharge:  surcharge
    ).call
  end

  context 'no adjustments' do
    it 'returns the original price unchanged' do
      result = call(unit_price: 1000.0)
      expect(result[:calculated_price]).to eq(1000.0)
      expect(result[:discount_amount]).to be_nil
      expect(result[:surcharge_amount]).to be_nil
    end
  end

  context 'percentage discount only' do
    let(:discount) { build(:adjustment, adjustment_type: 'discount', calculation_type: 'percentage', amount: 10.0) }

    it 'deducts 10% from the price' do
      result = call(unit_price: 1000.0, discount: discount)
      expect(result[:calculated_price]).to eq(900.0)
      expect(result[:discount_amount]).to eq(100.0)
    end
  end

  context 'fixed discount only' do
    let(:discount) { build(:adjustment, adjustment_type: 'discount', calculation_type: 'fixed', amount: 100.0) }

    it 'deducts the fixed net amount' do
      result = call(unit_price: 1000.0, discount: discount)
      expect(result[:calculated_price]).to eq(900.0)
      expect(result[:discount_amount]).to eq(100.0)
    end
  end

  context 'percentage surcharge only' do
    let(:surcharge) { build(:adjustment, adjustment_type: 'surcharge', calculation_type: 'percentage', amount: 5.0) }

    it 'adds 5% to the price' do
      result = call(unit_price: 1000.0, surcharge: surcharge)
      expect(result[:calculated_price]).to eq(1050.0)
      expect(result[:surcharge_amount]).to eq(50.0)
    end
  end

  context 'discount then surcharge applied in order' do
    let(:discount)  { build(:adjustment, adjustment_type: 'discount',  calculation_type: 'percentage', amount: 10.0) }
    let(:surcharge) { build(:adjustment, adjustment_type: 'surcharge', calculation_type: 'percentage', amount: 5.0) }

    it 'applies discount first, then surcharge on the reduced price' do
      # 1000 - 10% = 900, then 900 + 5% = 945
      result = call(unit_price: 1000.0, discount: discount, surcharge: surcharge)
      expect(result[:calculated_price]).to eq(945.0)
      expect(result[:discount_amount]).to eq(100.0)
      expect(result[:surcharge_amount]).to eq(45.0)
    end
  end

  context 'fixed discount cannot exceed item price' do
    let(:discount) { build(:adjustment, adjustment_type: 'discount', calculation_type: 'fixed', amount: 1500.0) }

    it 'caps discount_amount at the unit_price and returns calculated_price of 0' do
      result = call(unit_price: 1000.0, discount: discount)
      expect(result[:calculated_price]).to eq(0.0)
      expect(result[:discount_amount]).to eq(1000.0)
    end
  end
end
