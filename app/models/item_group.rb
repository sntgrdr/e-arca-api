# == Schema Information
#
# Table name: item_groups
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  details    :text
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_item_groups_on_user_id           (user_id)
#  index_item_groups_on_user_id_and_name  (user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ItemGroup < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false, allow_nil: true }

  scope :all_my_item_groups, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }
end
