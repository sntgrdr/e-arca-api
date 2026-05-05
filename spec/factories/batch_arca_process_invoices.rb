FactoryBot.define do
  factory :batch_arca_process_invoice do
    association :batch_arca_process
    invoice { create(:client_invoice, user: batch_arca_process.user, sell_point: batch_arca_process.sell_point) }
    arca_status { "pending" }
  end
end
