module Adjustments
  class CalculateService
    def initialize(unit_price:, discount: nil, surcharge: nil)
      @unit_price = unit_price.to_d
      @discount   = discount
      @surcharge  = surcharge
    end

    def call
      price            = @unit_price
      discount_amount  = nil
      surcharge_amount = nil

      if @discount
        raw             = apply(@discount, price)
        discount_amount = [@unit_price, raw].min.round(2)
        price           = (price - discount_amount).round(2)
      end

      if @surcharge
        surcharge_amount = apply(@surcharge, price).round(2)
        price            = (price + surcharge_amount).round(2)
      end

      {
        calculated_price: [price, 0.0.to_d].max.round(2),
        discount_amount:  discount_amount,
        surcharge_amount: surcharge_amount
      }
    end

    private

    def apply(adjustment, base_price)
      if adjustment.calculation_type == 'percentage'
        (base_price * adjustment.amount.to_d / 100.0)
      else
        adjustment.amount.to_d
      end
    end
  end
end
