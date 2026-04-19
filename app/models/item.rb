# == Schema Information
#
# Table name: items
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE), not null
#  code          :string
#  name          :string
#  price         :decimal(15, 4)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  item_group_id :bigint
#  iva_id        :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_items_on_item_group_id       (item_group_id)
#  index_items_on_iva_id              (iva_id)
#  index_items_on_user_id             (user_id)
#  index_items_on_user_id_and_active  (user_id,active)
#
# Foreign Keys
#
#  fk_rails_...  (item_group_id => item_groups.id)
#
class Item < ApplicationRecord
  belongs_to :iva
  belongs_to :user
  belongs_to :item_group, optional: true

  validates :name, :code, :price, presence: true
  validates :price, numericality: { greater_than: 0 }
  validates :code, uniqueness: { scope: :user_id, allow_nil: true }

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
