class LineSerializer < ActiveModel::Serializer
  attributes :id, :description, :quantity, :unit_price, :final_price,
             :iva_id, :item_id, :line_type,
             :original_price, :calculated_price,
             :applied_adjustment_id, :applied_adjustment_type, :applied_adjustment_amount

  belongs_to :iva, serializer: IvaSerializer
end
