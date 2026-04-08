class ClientGroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :active, :clients_count

  def clients_count
    object.clients.count
  end
end
