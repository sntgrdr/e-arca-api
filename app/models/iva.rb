class Iva < ApplicationRecord
  belongs_to :user

  scope :all_my_ivas, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where(active: true) }
end
