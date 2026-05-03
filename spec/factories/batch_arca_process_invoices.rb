FactoryBot.define do
  factory :batch_arca_process_invoice do
    association :batch_arca_process
    association :invoice, factory: :client_invoice
    arca_status { "pending" }
  end
end
