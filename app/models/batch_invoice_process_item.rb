# == Schema Information
#
# Table name: batch_invoice_process_items
#
#  id                       :bigint           not null, primary key
#  position                 :integer          default(0), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  batch_invoice_process_id :bigint           not null
#  item_id                  :bigint           not null
#
# Indexes
#
#  index_batch_invoice_process_items_on_batch_invoice_process_id  (batch_invoice_process_id)
#  index_batch_invoice_process_items_on_item_id                   (item_id)
#  index_bip_items_on_bip_id_and_item_id                          (batch_invoice_process_id,item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (batch_invoice_process_id => batch_invoice_processes.id)
#  fk_rails_...  (item_id => items.id)
#
class BatchInvoiceProcessItem < ApplicationRecord
  belongs_to :batch_invoice_process
  belongs_to :item

  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :item_id, uniqueness: { scope: :batch_invoice_process_id, allow_nil: true }
end
