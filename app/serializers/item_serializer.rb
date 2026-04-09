class ItemSerializer < ActiveModel::Serializer
  attributes :id, :code, :name, :price, :iva_id, :item_group_id, :active

  belongs_to :iva
end
