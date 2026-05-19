FactoryBot.define do
  factory :adjustment_applicable do
    association :adjustment
    association :applicable, factory: :item
  end
end
