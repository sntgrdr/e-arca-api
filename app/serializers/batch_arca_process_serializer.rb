class BatchArcaProcessSerializer < ActiveModel::Serializer
  attributes :id, :status, :invoice_class, :invoice_type, :sell_point_id,
             :total_invoices, :processed_invoices, :failed_invoices,
             :parent_batch_id, :error_message, :created_at
end
