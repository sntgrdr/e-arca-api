# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  account_number         :string           default(""), not null
#  active                 :boolean          default(TRUE)
#  activity_start         :date
#  address                :string
#  alias_account          :string           default(""), not null
#  arca_sign              :text
#  arca_token             :text
#  arca_token_expires_at  :datetime
#  cai                    :string           default(""), not null
#  city                   :string
#  country                :string
#  dni                    :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  legal_name             :string           default(""), not null
#  legal_number           :string           default(""), not null
#  locked_at              :datetime
#  name                   :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  state                  :string
#  tax_condition          :integer          default(NULL), not null
#  unlock_token           :string
#  zip_code               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_dni                              (dni) UNIQUE
#  index_users_on_email                            (email) UNIQUE
#  index_users_on_legal_name                       (legal_name) UNIQUE
#  index_users_on_legal_number_unique_except_ones  (legal_number) UNIQUE WHERE ((legal_number)::text <> '11-11111111-1'::text)
#  index_users_on_reset_password_token             (reset_password_token) UNIQUE
#  index_users_on_unlock_token                     (unlock_token) UNIQUE
#
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
