# == Schema Information
#
# Table name: batch_arca_process_invoices
#
#  id                    :bigint           not null, primary key
#  arca_error            :text
#  arca_status           :string           default("pending"), not null
#  processed_at          :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  batch_arca_process_id :bigint           not null
#  invoice_id            :bigint           not null
#
# Indexes
#
#  idx_batch_arca_invoices_uniqueness                          (batch_arca_process_id,invoice_id) UNIQUE
#  index_batch_arca_process_invoices_on_arca_status            (arca_status)
#  index_batch_arca_process_invoices_on_batch_arca_process_id  (batch_arca_process_id)
#  index_batch_arca_process_invoices_on_invoice_id             (invoice_id)
#
# Foreign Keys
#
#  fk_rails_...  (batch_arca_process_id => batch_arca_processes.id)
#  fk_rails_...  (invoice_id => invoices.id)
#
FactoryBot.define do
  factory :batch_arca_process_invoice do
    association :batch_arca_process
    invoice { create(:client_invoice, user: batch_arca_process.user, sell_point: batch_arca_process.sell_point) }
    arca_status { "pending" }
  end
end
