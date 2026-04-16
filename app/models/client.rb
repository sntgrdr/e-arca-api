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
class Client < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :iva, optional: true
  belongs_to :client_group, optional: true

  before_validation :sanitize_legal_number

  validates :legal_name, :legal_number, :tax_condition, presence: true
  validates :legal_name, :legal_number, uniqueness: { scope: :user_id, allow_nil: true }
  validates :final_client, uniqueness: { scope: :user_id }, if: -> { self[:final_client] }

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS

  scope :all_my_clients, ->(user_id) { where(user_id: user_id) }

  private

  def sanitize_legal_number
    self.legal_number = legal_number.gsub(/\D/, "") if legal_number.present?
  end
  scope :active, -> { where(active: true) }
end
