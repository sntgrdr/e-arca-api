class Invoice < ApplicationRecord
  include Discard::Model

  belongs_to :user
  belongs_to :client
  belongs_to :sell_point

  has_many :lines, as: :lineable, dependent: :destroy
  accepts_nested_attributes_for :lines, allow_destroy: true

  enum :afip_status, {
    draft: "draft",
    submitting: "submitting",
    authorized: "authorized",
    rejected: "rejected"
  }

  scope :kept, -> { undiscarded }

  VALID_INVOICE_TYPES = %w[A B C EA EB EC].freeze

  validates :number, :date, presence: true
  validates :number, uniqueness: {
    scope:     [ :user_id, :type, :sell_point_id, :invoice_type ],
    allow_nil: true
  }
  validates :number, numericality: { greater_than: 0 }
  validates :afip_status, presence: true
  validates :invoice_type, inclusion: { in: VALID_INVOICE_TYPES }, unless: :being_discarded?
  validates :total_price, numericality: { greater_than: 0 }, unless: :being_discarded?
  validate  :at_least_one_active_line, unless: :being_discarded?

  def self.current_number(user_id, sell_point_id, invoice_type)
    base = where(user_id: user_id, sell_point_id: sell_point_id, invoice_type: invoice_type)
    (base.maximum(Arel.sql("CAST(number AS INTEGER)")).to_i + 1).to_s
  end

  def self.all_my_invoices(user_id)
    kept.where(user_id: user_id)
  end

  def submittable?
    draft? || rejected?
  end

  def afip_authorized?
    cae.present?
  end

  private

  def being_discarded?
    will_save_change_to_discarded_at?
  end

  def at_least_one_active_line
    active = lines.reject(&:marked_for_destruction?)
    errors.add(:lines, :too_short) if active.empty?
  end
end
