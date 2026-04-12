class BatchInvoiceProcessItem < ApplicationRecord
  belongs_to :batch_invoice_process
  belongs_to :item

  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :item_id, uniqueness: { scope: :batch_invoice_process_id, allow_nil: true }
end
