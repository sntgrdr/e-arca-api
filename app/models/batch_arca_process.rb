# == Schema Information
#
# Table name: batch_arca_processes
#
#  id                 :bigint           not null, primary key
#  error_message      :text
#  failed_invoices    :integer          default(0), not null
#  idempotency_key    :string
#  invoice_class      :string           not null
#  invoice_type       :string           not null
#  processed_invoices :integer          default(0), not null
#  status             :string           default("pending"), not null
#  total_invoices     :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  parent_batch_id    :bigint
#  sell_point_id      :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_batch_arca_processes_on_parent_batch_id              (parent_batch_id)
#  index_batch_arca_processes_on_sell_point_id                (sell_point_id)
#  index_batch_arca_processes_on_status                       (status)
#  index_batch_arca_processes_on_user_id                      (user_id)
#  index_batch_arca_processes_on_user_id_and_idempotency_key  (user_id,idempotency_key) UNIQUE WHERE (idempotency_key IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (parent_batch_id => batch_arca_processes.id)
#  fk_rails_...  (sell_point_id => sell_points.id)
#  fk_rails_...  (user_id => users.id)
#
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

  scope :non_superseded, -> {
    where.not(id: where.not(parent_batch_id: nil).select(:parent_batch_id))
  }

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
    invoices.order(Arel.sql("CAST(invoices.number AS INTEGER) ASC"))
  end
end
