# == Schema Information
#
# Table name: adjustments
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  adjustment_type  :string           not null
#  amount           :decimal(15, 4)   not null
#  calculation_type :string           not null
#  deleted_at       :datetime
#  end_date         :date
#  start_date       :date             not null
#  target_type      :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  iva_id           :bigint
#  target_id        :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_adjustments_on_deleted_at                              (deleted_at)
#  index_adjustments_on_iva_id                                  (iva_id)
#  index_adjustments_on_target_type_and_target_id               (target_type,target_id)
#  index_adjustments_on_user_id                                 (user_id)
#  index_adjustments_on_user_id_and_adjustment_type_and_active  (user_id,adjustment_type,active)
#
# Foreign Keys
#
#  fk_rails_...  (iva_id => ivas.id)
#  fk_rails_...  (user_id => users.id)
#
class Adjustment < ApplicationRecord
  include Discard::Model
  self.discard_column = :deleted_at

  ADJUSTMENT_TYPES  = %w[discount surcharge].freeze
  CALCULATION_TYPES = %w[fixed percentage].freeze

  belongs_to :user
  belongs_to :iva, optional: true
  belongs_to :target, polymorphic: true
  has_many   :adjustment_applicables, dependent: :destroy

  validates :adjustment_type,  presence: true, inclusion: { in: ADJUSTMENT_TYPES }
  validates :calculation_type, presence: true, inclusion: { in: CALCULATION_TYPES }
  validates :amount,      presence: true, numericality: { greater_than: 0 }
  validates :start_date,  presence: true
  validates :iva_id,      presence: true, if: -> { calculation_type == "fixed" }

  validate :percentage_caps
  validate :end_date_after_start_date

  scope :active,   -> { where(active: true) }
  scope :valid_on, ->(date) {
    where(
      "start_date <= :d AND (end_date IS NULL OR end_date >= :d)",
      d: date
    )
  }

  private

  def percentage_caps
    return unless calculation_type == "percentage"

    if adjustment_type == "discount" && amount && amount > 100
      errors.add(:amount, "no puede superar el 100% para descuentos")
    elsif adjustment_type == "surcharge" && amount && amount > 200
      errors.add(:amount, "no puede superar el 200% para recargos")
    end
  end

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?

    errors.add(:end_date, "no puede ser anterior a la fecha de inicio") if end_date < start_date
  end
end
