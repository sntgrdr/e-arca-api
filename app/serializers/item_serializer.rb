class ItemSerializer < ActiveModel::Serializer
  attributes :id, :code, :name, :price, :price_with_iva, :iva_id, :item_group_id, :active

  belongs_to :iva
  belongs_to :item_group

  def price_with_iva
    return nil unless object.iva&.percentage
    (object.price * (1 + object.iva.percentage / 100.0)).round(2)
  end
end
