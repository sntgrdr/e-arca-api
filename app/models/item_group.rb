class ItemGroup < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false, allow_nil: true }

  scope :all_my_item_groups, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }
end
