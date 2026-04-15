class ClientGroupSerializer < ActiveModel::Serializer
  attributes :id, :name, :active, :details, :clients_count

  def clients_count
    object.clients.count
  end
end
