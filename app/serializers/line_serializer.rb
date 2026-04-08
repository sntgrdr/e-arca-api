class LineSerializer < ActiveModel::Serializer
  attributes :id, :description, :quantity, :unit_price, :final_price,
             :iva_id, :item_id

  belongs_to :iva
end
