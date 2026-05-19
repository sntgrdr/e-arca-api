class Adjustment < ApplicationRecord
  include Discard::Model
  self.discard_column = :deleted_at

  ADJUSTMENT_TYPES  = %w[discount surcharge].freeze
  CALCULATION_TYPES = %w[fixed percentage].freeze

  belongs_to :user
  belongs_to :target, polymorphic: true
  has_many   :adjustment_applicables, dependent: :destroy

  validates :adjustment_type,  presence: true, inclusion: { in: ADJUSTMENT_TYPES }
  validates :calculation_type, presence: true, inclusion: { in: CALCULATION_TYPES }
  validates :amount, presence: true, numericality: { greater_than: 0 }

  validate :percentage_caps

  scope :active,   -> { where(active: true) }
  scope :valid_on, ->(date) {
    where(
      "(start_date IS NULL OR start_date <= :d) AND (end_date IS NULL OR end_date >= :d)",
      d: date
    )
  }

  private

  def percentage_caps
    return unless calculation_type == 'percentage'

    if adjustment_type == 'discount' && amount && amount > 100
      errors.add(:amount, "no puede superar el 100% para descuentos")
    elsif adjustment_type == 'surcharge' && amount && amount > 200
      errors.add(:amount, "no puede superar el 200% para recargos")
    end
  end
end
