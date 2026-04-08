FactoryBot.define do
  factory :item do
    association :user
    association :iva
    sequence(:code) { |n| "ITEM#{n}" }
    name { 'Test Item' }
    price { 1210.0 }
  end
end
