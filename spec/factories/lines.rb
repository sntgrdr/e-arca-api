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
FactoryBot.define do
  factory :line do
    association :user
    association :item
    description { 'Test line item' }
    quantity { 1 }
    unit_price { 1000.0 }
    final_price { 1210.0 }
  end
end
