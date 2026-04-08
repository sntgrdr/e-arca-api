class ClientSerializer < ActiveModel::Serializer
  attributes :id, :legal_name, :legal_number, :name,
             :tax_condition, :iva_id, :client_group_id, :active

  belongs_to :iva
end
