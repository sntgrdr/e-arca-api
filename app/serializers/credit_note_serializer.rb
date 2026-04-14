class CreditNoteSerializer < ActiveModel::Serializer
  attributes :id, :number, :date, :period, :invoice_type, :total_price,
             :details, :client_invoice_id, :cae, :cae_expiration,
             :afip_invoice_number, :afip_result, :afip_authorized_at,
             :created_at, :can_edit, :can_send_to_arca, :client_invoice,
             :remaining_balance

  belongs_to :client
  belongs_to :sell_point
  has_many :lines

  def can_edit
    object.cae.blank?
  end

  def can_send_to_arca
    !object.authorized?
  end

  def client_invoice
    return nil unless object.client_invoice
    {
      id:           object.client_invoice.id,
      number:       object.client_invoice.number,
      invoice_type: object.client_invoice.invoice_type,
      total_price:  object.client_invoice.total_price,
      cae:          object.client_invoice.cae
    }
  end

  def remaining_balance
    return nil unless object.client_invoice
    already_credited = object.client_invoice.credit_notes.undiscarded.sum(:total_price)
    (object.client_invoice.total_price - already_credited).to_f
  end
end
