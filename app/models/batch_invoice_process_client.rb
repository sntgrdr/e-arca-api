# == Schema Information
#
# Table name: batch_invoice_process_clients
#
#  id                       :bigint           not null, primary key
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  batch_invoice_process_id :bigint           not null
#  client_id                :bigint           not null
#
# Indexes
#
#  idx_on_batch_invoice_process_id_c1f137dd10        (batch_invoice_process_id)
#  index_batch_invoice_process_clients_on_client_id  (client_id)
#  index_bip_clients_on_bip_id_and_client_id         (batch_invoice_process_id,client_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (batch_invoice_process_id => batch_invoice_processes.id)
#  fk_rails_...  (client_id => clients.id)
#
class BatchInvoiceProcessClient < ApplicationRecord
  belongs_to :batch_invoice_process
  belongs_to :client

  validates :client_id, uniqueness: { scope: :batch_invoice_process_id, allow_nil: true }
end
