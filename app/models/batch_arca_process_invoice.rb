class BatchArcaProcessInvoice < ApplicationRecord
  belongs_to :batch_arca_process
  belongs_to :invoice

  validates :arca_status, presence: true

  enum :arca_status, {
    pending:    "pending",
    processing: "processing",
    authorized: "authorized",
    failed:     "failed",
    blocked:    "blocked"
  }

  scope :unprocessed, -> { where(arca_status: %w[pending blocked]) }
end
