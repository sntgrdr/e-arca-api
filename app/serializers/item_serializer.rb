class ItemSerializer < ActiveModel::Serializer
  attributes :id, :code, :name, :price, :price_with_iva, :iva_id, :item_group_id, :item_group_name, :active

  belongs_to :iva

  def price_with_iva
    object.price_with_iva
  end

  def item_group_name
    object.item_group&.name
  end
end
