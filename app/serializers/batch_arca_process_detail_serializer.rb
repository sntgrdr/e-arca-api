class BatchArcaProcessDetailSerializer < ActiveModel::Serializer
  attributes :id, :status, :invoice_class, :invoice_type, :sell_point_id,
             :total_invoices, :processed_invoices, :failed_invoices,
             :error_message, :created_at

  has_many :batch_arca_process_invoices, key: :invoices, serializer: BatchArcaProcessInvoiceSerializer

  def batch_arca_process_invoices
    object.batch_arca_process_invoices
          .includes(invoice: :client)
          .joins(:invoice)
          .order(Arel.sql("CAST(invoices.number AS INTEGER) ASC"))
  end
end
