class SellPoint < ApplicationRecord
  belongs_to :user
  has_many :invoices, dependent: :restrict_with_error

  scope :all_my_sell_points, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }

  validate :only_one_default_per_user, if: -> { self.default? && default_changed? }

  def name_to_s
    "#{number} - #{name}"
  end

  private

  def only_one_default_per_user
    existing = SellPoint.where(user_id: user_id, default: true).where.not(id: id).first
    return unless existing

    errors.add(:base, "No es posible establecer como predeterminado porque el punto de venta #{existing.number} ya es el predeterminado")
  end
end
