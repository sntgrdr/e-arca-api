FactoryBot.define do
  factory :client_group do
    association :user
    sequence(:name) { |n| "Grupo #{n}" }
  end
end
