# app/models/batch_invoice_process.rb
class BatchInvoiceProcess < ApplicationRecord
  MAX_ITEMS   = 10
  MAX_CLIENTS = 100

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

  validates :date, :period, :status, presence: true

  enum :status, {
    pending:    "pending",
    processing: "processing",
    completed:  "completed",
    failed:     "failed"
  }

  scope :all_my_processes, ->(user_id) { where(user_id: user_id) }

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
end
