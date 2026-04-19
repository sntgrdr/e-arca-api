# == Schema Information
#
# Table name: invoices
#
#  id                       :bigint           not null, primary key
#  afip_authorized_at       :datetime
#  afip_invoice_number      :string
#  afip_response_xml        :text
#  afip_result              :string
#  afip_status              :string           default("draft"), not null
#  cae                      :string
#  cae_expiration           :date
#  date                     :date             not null
#  details                  :text
#  discarded_at             :datetime
#  invoice_type             :string           default("C"), not null
#  number                   :string           not null
#  period                   :date             not null
#  total_price              :decimal(15, 4)
#  type                     :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  batch_invoice_process_id :bigint
#  client_id                :bigint           not null
#  client_invoice_id        :bigint
#  sell_point_id            :bigint           not null
#  user_id                  :bigint           not null
#
# Indexes
#
#  idx_unique_sellpoint_type_invoice_type_number  (sell_point_id,type,invoice_type,number) UNIQUE WHERE ((discarded_at IS NULL) OR (cae IS NOT NULL))
#  index_invoices_on_afip_status                  (afip_status)
#  index_invoices_on_batch_invoice_process_id     (batch_invoice_process_id)
#  index_invoices_on_client_id                    (client_id)
#  index_invoices_on_client_invoice_id            (client_invoice_id)
#  index_invoices_on_discarded_at                 (discarded_at)
#  index_invoices_on_sell_point_id                (sell_point_id)
#  index_invoices_on_user_id                      (user_id)
#  index_invoices_on_user_id_and_client_id        (user_id,client_id)
#  index_invoices_on_user_id_type_created_at      (user_id,type,created_at)
#  index_invoices_on_user_id_type_date            (user_id,type,date)
#
# Foreign Keys
#
#  fk_rails_...  (batch_invoice_process_id => batch_invoice_processes.id)
#  fk_rails_...  (client_id => clients.id)
#  fk_rails_...  (client_invoice_id => invoices.id)
#  fk_rails_...  (sell_point_id => sell_points.id)
#  fk_rails_...  (user_id => users.id)
#
class ClientInvoice < Invoice
  has_paper_trail

  include Reportable

  belongs_to :batch_invoice_process, optional: true

  has_many :credit_notes,
           foreign_key: :client_invoice_id,
           dependent: :nullify

  def afip_code
    case invoice_type
    when "A", "EA" then "1"
    when "B", "EB" then "6"
    when "C", "EC" then "11"
    end
  end
end
