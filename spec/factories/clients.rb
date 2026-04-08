FactoryBot.define do
  factory :client do
    association :user
    association :iva
    sequence(:legal_name) { |n| "Cliente Test #{n}" }
    sequence(:legal_number) { |n| "30-#{n.to_s.rjust(8, '0')}-5" }
    tax_condition { :final_client }
  end
end
