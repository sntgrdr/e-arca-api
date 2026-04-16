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
class CreditNote < Invoice
  has_paper_trail

  include Reportable

  belongs_to :client_invoice,
             class_name: "ClientInvoice",
             optional: true

  validate :client_invoice_is_authorized,        unless: :being_discarded?
  validate :client_invoice_belongs_to_user,      unless: :being_discarded?
  validate :sell_point_matches_client_invoice,   unless: :being_discarded?
  validate :invoice_type_matches_client_invoice, unless: :being_discarded?
  validate :period_matches_client_invoice,       unless: :being_discarded?
  validate :total_within_available,              unless: :being_discarded?

  def afip_code
    case invoice_type
    when "A", "EA" then "3"
    when "B", "EB" then "8"
    when "C", "EC" then "13"
    end
  end

  def associated_cbte_tipo
    client_invoice.afip_code
  end

  def associated_cbte_punto_vta
    client_invoice.sell_point.number
  end

  def associated_cbte_numero
    client_invoice.number
  end

  def has_associated_cbte?
    true
  end

  private

  def client_invoice_is_authorized
    return unless client_invoice
    errors.add(:client_invoice, :not_authorized) unless client_invoice.cae.present?
  end

  def client_invoice_belongs_to_user
    return unless client_invoice
    errors.add(:client_invoice, :not_owned) unless client_invoice.user_id == user_id
  end

  def sell_point_matches_client_invoice
    return unless client_invoice
    errors.add(:sell_point, :mismatch) unless sell_point_id == client_invoice.sell_point_id
  end

  def invoice_type_matches_client_invoice
    return unless client_invoice
    errors.add(:invoice_type, :mismatch) unless invoice_type == client_invoice.invoice_type
  end

  def period_matches_client_invoice
    return unless client_invoice
    return if period.blank? || client_invoice.period.blank?
    errors.add(:period, :mismatch) unless period.to_s == client_invoice.period.to_s
  end

  def other_credit_notes
    scope = client_invoice.credit_notes.undiscarded
    scope = scope.where.not(id: id) if persisted?
    scope
  end

  def total_within_available
    return unless client_invoice
    return unless total_price.present?

    already_credited = other_credit_notes.sum(:total_price).to_f
    remaining = client_invoice.total_price.to_f - already_credited

    if total_price.to_f > remaining
      errors.add(:total_price, :exceeds_available, remaining: remaining.round(2))
    end
  end
end
