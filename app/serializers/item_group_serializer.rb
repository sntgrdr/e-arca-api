class ItemGroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :active, :items_count

  def items_count
    object.items.count
  end
end
