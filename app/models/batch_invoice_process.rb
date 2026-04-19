# app/models/batch_invoice_process.rb
# == Schema Information
#
# Table name: batch_invoice_processes
#
#  id                 :bigint           not null, primary key
#  date               :date             not null
#  error_details      :jsonb
#  error_message      :text
#  failed_invoices    :integer          default(0), not null
#  invoice_type       :string
#  pdf_generated      :boolean          default(FALSE), not null
#  period             :date             not null
#  process_type       :string           default("per_client"), not null
#  processed_invoices :integer          default(0), not null
#  quantity           :integer
#  status             :string           default("pending"), not null
#  total_invoices     :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  client_group_id    :bigint
#  item_id            :bigint
#  sell_point_id      :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_batch_invoice_processes_on_client_group_id  (client_group_id)
#  index_batch_invoice_processes_on_item_id          (item_id)
#  index_batch_invoice_processes_on_sell_point_id    (sell_point_id)
#  index_batch_invoice_processes_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_group_id => client_groups.id)
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (sell_point_id => sell_points.id)
#  fk_rails_...  (user_id => users.id)
#
class BatchInvoiceProcess < ApplicationRecord
  MAX_ITEMS    = 10
  MAX_CLIENTS  = 100
  MAX_QUANTITY = 200

  belongs_to :user
  belongs_to :client_group, optional: true
  belongs_to :item, optional: true
  belongs_to :sell_point

  has_many :batch_invoice_process_items,   dependent: :destroy
  has_many :batch_items, through: :batch_invoice_process_items, source: :item

  has_many :batch_invoice_process_clients, dependent: :destroy
  has_many :selected_clients, through: :batch_invoice_process_clients, source: :client

  has_many :client_invoices, dependent: :nullify
  has_one_attached :pdf_zip

  before_validation :set_default_invoice_type

  validates :date, :period, :status, presence: true
  validates :quantity,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_QUANTITY },
            if: :final_consumer?

  enum :status, {
    pending:    "pending",
    processing: "processing",
    completed:  "completed",
    failed:     "failed"
  }

  enum :process_type, {
    per_client:     "per_client",
    final_consumer: "final_consumer"
  }

  scope :all_my_processes, ->(user_id) { where(user_id: user_id) }

  def processor
    case process_type
    when "per_client"     then BatchInvoiceProcessors::PerClient.new(self)
    when "final_consumer" then BatchInvoiceProcessors::FinalConsumer.new(self)
    end
  end

  # Returns the items to use for invoice lines.
  # Falls back to the legacy single item when no join table entries exist.
  def resolved_items
    entries = batch_items.order("batch_invoice_process_items.position ASC")
    entries.any? ? entries : [ item ].compact
  end

  # Returns the clients to invoice.
  # Priority: explicit selection → group → all user's active clients.
  def resolved_clients
    has_explicit_clients = selected_clients.loaded? ? selected_clients.any? : batch_invoice_process_clients.exists?
    if has_explicit_clients
      selected_clients
    elsif client_group_id?
      client_group.clients.where(active: true)
    else
      Client.all_my_clients(user_id).active
    end
  end

  private

  def set_default_invoice_type
    return if invoice_type.present?
    self.invoice_type = user&.registered? ? "B" : "C"
  end
end
