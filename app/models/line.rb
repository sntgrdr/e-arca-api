# == Schema Information
#
# Table name: lines
#
#  id                        :bigint           not null, primary key
#  applied_adjustment_amount :decimal(15, 4)
#  applied_adjustment_type   :string
#  calculated_price          :decimal(15, 4)
#  description               :string
#  final_price               :decimal(15, 4)
#  line_type                 :string           default("item"), not null
#  lineable_type             :string
#  original_price            :decimal(15, 4)
#  quantity                  :decimal(6, 2)
#  unit_price                :decimal(15, 4)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  applied_adjustment_id     :bigint
#  item_id                   :bigint
#  iva_id                    :bigint
#  lineable_id               :bigint
#  user_id                   :bigint
#
# Indexes
#
#  index_lines_on_applied_adjustment_id  (applied_adjustment_id)
#  index_lines_on_item_id                (item_id)
#  index_lines_on_iva_id                 (iva_id)
#  index_lines_on_line_type              (line_type)
#  index_lines_on_user_id                (user_id)
#
class Line < ApplicationRecord
  belongs_to :lineable, polymorphic: true
  belongs_to :item, optional: true
  belongs_to :user
  belongs_to :iva, optional: true

  TYPES = %w[item adjustment].freeze

  validates :unit_price, :quantity, :description, presence: true
  validates :final_price, presence: true
  validates :line_type, presence: true, inclusion: { in: TYPES }
  validates :unit_price, :quantity, numericality: { greater_than: 0 }
  validates :final_price, numericality: { greater_than: 0 }, if: -> { line_type == 'item' }
  validates :item, presence: true, if: -> { line_type == 'item' }
end
