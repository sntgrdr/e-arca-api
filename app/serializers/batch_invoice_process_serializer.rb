class BatchInvoiceProcessSerializer < ActiveModel::Serializer
  attributes :id, :status, :process_type, :date, :period, :total_invoices,
             :processed_invoices, :failed_invoices, :pdf_generated,
             :error_message, :client_group_id, :item_id, :sell_point_id,
             :invoice_type, :quantity, :created_at, :item, :sell_point, :items, :client_group

  def item
    return nil unless object.item
    { id: object.item.id, name: object.item.name, code: object.item.code }
  end

  def sell_point
    return nil unless object.sell_point
    { id: object.sell_point.id, number: object.sell_point.number }
  end

  def items
    resolved = object.resolved_items
    resolved.map { |i| { id: i.id, name: i.name, code: i.code } }
  end

  def client_group
    return nil unless object.client_group
    { id: object.client_group.id, name: object.client_group.name }
  end
end
