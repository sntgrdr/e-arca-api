class BatchInvoiceProcessClient < ApplicationRecord
  belongs_to :batch_invoice_process
  belongs_to :client

  validates :client_id, uniqueness: { scope: :batch_invoice_process_id, allow_nil: true }
end
