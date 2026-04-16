# == Schema Information
#
# Table name: client_groups
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
#  index_client_groups_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ClientGroup < ApplicationRecord
  belongs_to :user
  has_many :clients, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, allow_nil: true }

  scope :all_my_client_groups, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }
end
