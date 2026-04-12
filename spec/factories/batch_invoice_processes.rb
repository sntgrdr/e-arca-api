# spec/factories/batch_invoice_processes.rb
FactoryBot.define do
  factory :batch_invoice_process do
    association :user
    association :item
    association :sell_point
    date               { Date.current }
    period             { Date.current }
    status             { 'pending' }
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
      error_details { [ { client_id: 1, error: 'AFIP timeout' } ] }
    end

    trait :with_items do
      transient do
        items_list { [] }
      end

      after(:create) do |batch, evaluator|
        evaluator.items_list.each_with_index do |item, position|
          create(:batch_invoice_process_item,
                 batch_invoice_process: batch,
                 item: item,
                 position: position)
        end
      end
    end

    trait :with_selected_clients do
      transient do
        clients_list { [] }
      end

      after(:create) do |batch, evaluator|
        evaluator.clients_list.each do |client|
          create(:batch_invoice_process_client,
                 batch_invoice_process: batch,
                 client: client)
        end
      end
    end
  end

  factory :batch_invoice_process_item do
    association :batch_invoice_process
    association :item
    position { 0 }
  end

  factory :batch_invoice_process_client do
    association :batch_invoice_process
    association :client
  end
end
