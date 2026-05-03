class BatchArcaProcess < ApplicationRecord
  MAX_INVOICES    = 100
  ALLOWED_CLASSES = %w[ClientInvoice CreditNote].freeze

  belongs_to :user
  belongs_to :sell_point
  belongs_to :parent_batch, class_name: "BatchArcaProcess", optional: true

  has_many :batch_arca_process_invoices, dependent: :destroy
  has_many :invoices, through: :batch_arca_process_invoices

  validates :invoice_class, presence: true, inclusion: { in: ALLOWED_CLASSES }
  validates :invoice_type,  presence: true
  validates :status,        presence: true

  enum :status, {
    pending:    "pending",
    processing: "processing",
    completed:  "completed",
    failed:     "failed"
  }

  def retryable?
    failed?
  end

  def invoices_ordered
    invoices.order("CAST(invoices.number AS INTEGER) ASC")
  end
end
