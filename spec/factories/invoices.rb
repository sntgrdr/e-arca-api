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

    trait :with_cae do
      cae { '12345678901234' }
      cae_expiration { 10.days.from_now.to_date }
      afip_invoice_number { '1' }
      afip_result { 'A' }
      afip_authorized_at { Time.current }
      afip_status { :authorized }
    end

    trait :with_lines do
      after(:create) do |invoice|
        iva = create(:iva, user: invoice.user)
        item = create(:item, user: invoice.user, iva: iva)
        create(:line, lineable: invoice, user: invoice.user, item: item, iva: iva,
               description: 'Servicio mensual', quantity: 1,
               unit_price: 1000.0, final_price: 1000.0)
      end
    end
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
