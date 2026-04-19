# == Schema Information
#
# Table name: ivas
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  percentage :decimal(5, 2)    not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_ivas_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Iva < ApplicationRecord
  belongs_to :user

  scope :all_my_ivas, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }
end
