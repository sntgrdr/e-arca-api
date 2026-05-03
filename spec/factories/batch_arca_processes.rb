FactoryBot.define do
  factory :batch_arca_process do
    association :user
    association :sell_point
    invoice_class      { "ClientInvoice" }
    invoice_type       { "C" }
    status             { "pending" }
    total_invoices     { 0 }
    processed_invoices { 0 }
    failed_invoices    { 0 }
  end
end
