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

  before_validation :strip_iva_from_fixed_amount,
    if: -> { calculation_type == 'fixed' && will_save_change_to_amount? }

  validate :percentage_caps
  validate :fixed_requires_item_applicable, if: -> { calculation_type == 'fixed' }

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

  def strip_iva_from_fixed_amount
    item_applicable = adjustment_applicables.find { |a| a.applicable_type == 'Item' }
    return unless item_applicable

    item = Item.find_by(id: item_applicable.applicable_id)
    return unless item&.iva&.percentage.to_f > 0

    self.amount = (amount.to_d / (1 + item.iva.percentage / 100.0)).round(4)
  end

  def fixed_requires_item_applicable
    types = adjustment_applicables.map(&:applicable_type)
    return if types.empty?

    unless types.all? { |t| t == 'Item' }
      errors.add(:calculation_type, "fijo solo puede aplicarse a ítems específicos")
    end
  end
end
