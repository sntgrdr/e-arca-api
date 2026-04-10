class BatchClientInvoiceSerializer < ActiveModel::Serializer
  attributes :id, :number, :date, :cae, :afip_authorized_at, :total_price,
             :client_name, :client_legal_number

  def client_name
    object.client.legal_name
  end

  def client_legal_number
    object.client.legal_number
  end
end
