class ItemSerializer < ActiveModel::Serializer
  attributes :id, :code, :name, :price, :iva_id, :active

  belongs_to :iva
end
