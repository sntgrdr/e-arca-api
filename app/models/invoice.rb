class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :client
  belongs_to :sell_point

  has_many :lines, as: :lineable, dependent: :destroy
  accepts_nested_attributes_for :lines, allow_destroy: true

  validates :number, :date, presence: true
  validates :number, uniqueness: { scope: [:user_id, :type, :sell_point_id] }
  validates :number, numericality: { greater_than: 0 }

  def self.current_number(user_id, sell_point_id)
    (where(user_id: user_id, sell_point_id: sell_point_id).maximum(Arel.sql('CAST(number AS INTEGER)')).to_i + 1).to_s
  end

  def self.all_my_invoices(user_id)
    where(user_id: user_id)
  end
end
