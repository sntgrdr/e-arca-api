class BatchInvoiceProcess < ApplicationRecord
  belongs_to :user
  belongs_to :client_group, optional: true
  belongs_to :item
  belongs_to :sell_point

  has_many :client_invoices, dependent: :nullify

  has_one_attached :pdf_zip

  validates :date, :period, :status, presence: true

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  scope :all_my_processes, ->(user_id) { where(user_id: user_id) }
end
