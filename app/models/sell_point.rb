# == Schema Information
#
# Table name: sell_points
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  default    :boolean          default(FALSE), not null
#  name       :string
#  number     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_sell_points_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
