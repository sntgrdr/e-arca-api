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
#  sell_point_id      :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_batch_arca_processes_on_sell_point_id                (sell_point_id)
#  index_batch_arca_processes_on_status                       (status)
#  index_batch_arca_processes_on_user_id                      (user_id)
#  index_batch_arca_processes_on_user_id_and_idempotency_key  (user_id,idempotency_key) UNIQUE WHERE (idempotency_key IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (sell_point_id => sell_points.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :batch_arca_process do
    association :user
    association :sell_point
    invoice_class      { "ClientInvoice" }
    invoice_type       { "C" }
    status             { "pending" }
    total_invoices     { 0 }
    processed_invoices { 0 }
    failed_invoices    { 0 }
  end
end
