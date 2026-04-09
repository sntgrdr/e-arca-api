FactoryBot.define do
  factory :batch_invoice_process do
    association :user
    association :item
    association :sell_point
    date   { Date.current }
    period { Date.current }
    status { 'pending' }
    processed_invoices { 0 }
    total_invoices     { 0 }
    pdf_generated      { false }

    trait :with_client_group do
      association :client_group
    end

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
    end
  end
end
