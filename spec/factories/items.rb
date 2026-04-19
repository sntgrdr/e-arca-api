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
FactoryBot.define do
  factory :item do
    association :user
    association :iva
    sequence(:code) { |n| "ITEM#{n}" }
    name { 'Test Item' }
    price { 1210.0 }
  end
end
