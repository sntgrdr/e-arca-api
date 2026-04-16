# spec/factories/batch_invoice_processes.rb
# == Schema Information
#
# Table name: batch_invoice_processes
#
#  id                 :bigint           not null, primary key
#  date               :date             not null
#  error_details      :jsonb
#  error_message      :text
#  failed_invoices    :integer          default(0), not null
#  invoice_type       :string
#  pdf_generated      :boolean          default(FALSE), not null
#  period             :date             not null
#  process_type       :string           default("per_client"), not null
#  processed_invoices :integer          default(0), not null
#  quantity           :integer
#  status             :string           default("pending"), not null
#  total_invoices     :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  client_group_id    :bigint
#  item_id            :bigint
#  sell_point_id      :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_batch_invoice_processes_on_client_group_id  (client_group_id)
#  index_batch_invoice_processes_on_item_id          (item_id)
#  index_batch_invoice_processes_on_sell_point_id    (sell_point_id)
#  index_batch_invoice_processes_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_group_id => client_groups.id)
#  fk_rails_...  (item_id => items.id)
#  fk_rails_...  (sell_point_id => sell_points.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :batch_invoice_process do
    association :user
    association :item
    association :sell_point
    date               { Date.current }
    period             { Date.current }
    status             { 'pending' }
    process_type       { 'per_client' }
    invoice_type       { 'C' }
    processed_invoices { 0 }
    total_invoices     { 0 }
    pdf_generated      { false }

    trait :final_consumer do
      process_type { 'final_consumer' }
      item         { nil }
      quantity     { 5 }
    end

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
