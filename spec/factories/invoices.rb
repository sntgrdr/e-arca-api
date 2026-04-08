FactoryBot.define do
  factory :client_invoice do
    association :user
    association :client
    association :sell_point
    sequence(:number) { |n| n.to_s }
    date { Date.current }
    period { Date.current }
    invoice_type { 'C' }
    total_price { 1000.0 }
  end

  factory :credit_note do
    association :user
    association :client
    association :sell_point
    association :client_invoice
    sequence(:number) { |n| n.to_s }
    date { Date.current }
    period { Date.current }
    invoice_type { 'C' }
    total_price { 500.0 }
  end
end
