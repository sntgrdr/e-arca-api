class SellPointSerializer < ActiveModel::Serializer
  attributes :id, :number, :name, :active, :default
end
