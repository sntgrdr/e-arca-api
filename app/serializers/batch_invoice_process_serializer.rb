class BatchInvoiceProcessSerializer < ActiveModel::Serializer
  attributes :id, :status, :date, :period, :total_invoices,
             :processed_invoices, :failed_invoices, :pdf_generated,
             :error_message, :client_group_id, :item_id, :sell_point_id,
             :created_at, :item, :sell_point

  def item
    return nil unless object.item
    { id: object.item.id, name: object.item.name, code: object.item.code }
  end

  def sell_point
    return nil unless object.sell_point
    { id: object.sell_point.id, number: object.sell_point.number }
  end
end
