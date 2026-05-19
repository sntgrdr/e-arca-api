FactoryBot.define do
  factory :adjustment do
    association :user
    association :target, factory: :client
    adjustment_type  { 'discount' }
    calculation_type { 'percentage' }
    amount           { 10.0 }
    active           { true }
    start_date       { nil }
    end_date         { nil }
  end
end
