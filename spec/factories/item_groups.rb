FactoryBot.define do
  factory :item_group do
    association :user
    sequence(:name) { |n| "Grupo Items #{n}" }
  end
end
