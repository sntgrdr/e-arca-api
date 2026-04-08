class ClientInvoiceSerializer < ActiveModel::Serializer
  attributes :id, :number, :date, :period, :invoice_type, :total_price,
             :details, :cae, :cae_expiration, :afip_invoice_number,
             :afip_result, :afip_authorized_at, :created_at

  belongs_to :client
  belongs_to :sell_point
  has_many :lines
  has_many :credit_notes, key: :credit_note_ids do
    object.credit_notes.pluck(:id)
  end
end
