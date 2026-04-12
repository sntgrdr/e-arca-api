FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'Secure.pass1' }
    sequence(:legal_name) { |n| "Empresa Test #{n}" }
    sequence(:legal_number) { |n| "20-#{n.to_s.rjust(8, '0')}-9" }
    sequence(:dni) { |n| n.to_s.rjust(8, '0') }
    tax_condition { :registered }
    name { 'Test User' }
    address { 'Calle Test 123' }
    city { 'Buenos Aires' }
    state { 'CABA' }
    country { 'Argentina' }
    zip_code { '1000' }
    cai { '' }
    account_number { '' }
    alias_account { '' }
  end
end
