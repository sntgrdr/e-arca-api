class BatchArcaProcessDetailSerializer < ActiveModel::Serializer
  attributes :id, :status, :invoice_class, :invoice_type, :sell_point_id,
             :total_invoices, :processed_invoices, :failed_invoices,
             :parent_batch_id, :error_message, :created_at

  has_many :batch_arca_process_invoices, serializer: BatchArcaProcessInvoiceSerializer

  def batch_arca_process_invoices
    object.batch_arca_process_invoices
          .includes(invoice: :client)
          .joins(:invoice)
          .order("CAST(invoices.number AS INTEGER) ASC")
  end
end
