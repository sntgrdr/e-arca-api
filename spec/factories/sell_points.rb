# == Schema Information
#
# Table name: sell_points
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  default    :boolean          default(FALSE), not null
#  name       :string
#  number     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_sell_points_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :sell_point do
    association :user
    sequence(:number) { |n| n.to_s }
    name { 'Punto de Venta' }
  end
end
