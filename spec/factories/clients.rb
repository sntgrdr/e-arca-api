# == Schema Information
#
# Table name: clients
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE)
#  dni             :string
#  final_client    :boolean          default(FALSE), not null
#  legal_name      :string           default(""), not null
#  legal_number    :string           default(""), not null
#  name            :string
#  tax_condition   :integer          default(NULL), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  client_group_id :bigint
#  iva_id          :bigint
#  user_id         :bigint
#
# Indexes
#
#  index_clients_on_client_group_id              (client_group_id)
#  index_clients_on_iva_id                       (iva_id)
#  index_clients_on_legal_name                   (legal_name) USING gin
#  index_clients_on_name                         (name) USING gin
#  index_clients_on_user_id                      (user_id)
#  index_clients_on_user_id_and_active           (user_id,active)
#  index_clients_on_user_id_and_legal_name       (user_id,legal_name)
#  index_clients_on_user_id_final_client_unique  (user_id,final_client) UNIQUE WHERE (final_client = true)
#
# Foreign Keys
#
#  fk_rails_...  (client_group_id => client_groups.id)
#  fk_rails_...  (iva_id => ivas.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :client do
    association :user
    association :iva
    sequence(:legal_name) { |n| "Cliente Test #{n}" }
    sequence(:legal_number) { |n| "30-#{n.to_s.rjust(8, '0')}-5" }
    tax_condition { :final_client }
  end
end
