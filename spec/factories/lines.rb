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
