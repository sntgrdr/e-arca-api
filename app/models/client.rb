class Client < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :iva
  belongs_to :client_group, optional: true

  validates :legal_name, :legal_number, :tax_condition, presence: true
  validates :legal_name, :legal_number, uniqueness: { scope: :user_id }

  enum :tax_condition, ::Constants::Arca::TAX_CONDITIONS

  scope :all_my_clients, ->(user_id) { where(user_id: user_id, active: true) }
  scope :active, -> { where(active: true) }
end
