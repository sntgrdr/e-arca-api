# == Schema Information
#
# Table name: lines
#
#  id            :bigint           not null, primary key
#  description   :string
#  final_price   :decimal(15, 4)
#  lineable_type :string
#  quantity      :decimal(6, 2)
#  unit_price    :decimal(15, 4)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  item_id       :bigint
#  iva_id        :bigint
#  lineable_id   :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_lines_on_item_id  (item_id)
#  index_lines_on_iva_id   (iva_id)
#  index_lines_on_user_id  (user_id)
#
class Line < ApplicationRecord
  belongs_to :lineable, polymorphic: true
  belongs_to :item
  belongs_to :user
  belongs_to :iva, optional: true

  validates :unit_price, :final_price, :quantity, :description, presence: true
  validates :unit_price, :final_price, :quantity, numericality: { greater_than: 0 }
end
