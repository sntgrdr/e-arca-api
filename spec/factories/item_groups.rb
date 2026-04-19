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
FactoryBot.define do
  factory :item_group do
    association :user
    sequence(:name) { |n| "Grupo Items #{n}" }
  end
end
