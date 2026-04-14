class ClientInvoiceDetailSerializer < ActiveModel::Serializer
  attributes :id, :number, :date, :period, :invoice_type, :total_price,
             :details, :cae, :cae_expiration, :afip_invoice_number,
             :afip_result, :afip_authorized_at, :created_at,
             :sell_point, :client, :lines, :credit_notes,
             :can_edit, :can_send_to_arca, :can_create_credit_note

  def sell_point
    return nil unless object.sell_point
    { id: object.sell_point.id, number: object.sell_point.number }
  end

  def client
    return nil unless object.client
    {
      id:             object.client.id,
      legal_name:     object.client.legal_name,
      legal_number:   object.client.legal_number,
      tax_condition:  object.client.tax_condition
    }
  end

  def lines
    object.lines.map do |line|
      {
        id:          line.id,
        item_id:     line.item_id,
        description: line.description,
        quantity:    line.quantity,
        unit_price:  line.unit_price,
        final_price: line.final_price,
        iva_id:      line.iva_id,
        iva:         line.iva && {
          id:         line.iva.id,
          name:       line.iva.name,
          percentage: line.iva.percentage
        }
      }
    end
  end

  def credit_notes
    object.credit_notes.map do |cn|
      {
        id:          cn.id,
        number:      cn.number,
        date:        cn.date,
        total_price: cn.total_price,
        cae:         cn.cae
      }
    end
  end

  def can_edit
    object.cae.blank?
  end

  def can_send_to_arca
    !object.authorized?
  end

  def can_create_credit_note
    object.cae.present?
  end
end
