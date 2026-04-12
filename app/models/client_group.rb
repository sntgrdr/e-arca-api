class ClientGroup < ApplicationRecord
  belongs_to :user
  has_many :clients, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, allow_nil: true }

  scope :all_my_client_groups, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }
end
