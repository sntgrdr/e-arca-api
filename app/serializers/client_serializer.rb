class ClientSerializer < ActiveModel::Serializer
  attributes :id, :legal_name, :legal_number, :name,
             :tax_condition, :iva_id, :client_group_id, :client_group_name, :active

  belongs_to :iva

  def client_group_name
    object.client_group&.name
  end
end
