class BatchInvoiceProcessSerializer < ActiveModel::Serializer
  attributes :id, :status, :date, :period, :total_invoices,
             :processed_invoices, :pdf_generated, :error_message,
             :client_group_id, :item_id, :sell_point_id, :created_at
end
