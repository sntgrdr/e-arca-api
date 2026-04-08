class Item < ApplicationRecord
  belongs_to :iva
  belongs_to :user

  validates :name, :code, :price, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :code, uniqueness: { scope: :user_id }

  scope :all_my_items, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }

  before_validation :upcase_code
  before_save :subtract_iva_from_price, if: -> { price_changed? || iva_id_changed? }

  def upcase_code
    self.code = code&.upcase
  end

  private

  def subtract_iva_from_price
    return unless price.present? && iva&.percentage.present?

    self.price = price / (1 + (iva.percentage / 100.0))
  end
end
