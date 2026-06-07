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
FactoryBot.define do
  factory :line do
    association :lineable, factory: :client_invoice
    association :user
    association :item
    description { 'Test line item' }
    quantity { 1 }
    unit_price { 1000.0 }
    final_price { 1210.0 }
    line_type { 'item' }
  end

  factory :adjustment_line, parent: :line do
    association :item
    line_type { 'adjustment' }
    unit_price { 100.0 }
    final_price { -100.0 }
    description { 'Descuento 10%' }
    applied_adjustment_type { 'discount' }
    applied_adjustment_amount { 100.0 }
  end
end
