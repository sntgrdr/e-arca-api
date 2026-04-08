FactoryBot.define do
  factory :iva do
    association :user
    name { 'IVA 21%' }
    percentage { 21.0 }
  end
end
