# == Schema Information
#
# Table name: adjustments
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  adjustment_type  :string           not null
#  amount           :decimal(15, 4)   not null
#  calculation_type :string           not null
#  deleted_at       :datetime
#  end_date         :date
#  start_date       :date             not null
#  target_type      :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  iva_id           :bigint
#  target_id        :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_adjustments_on_deleted_at                              (deleted_at)
#  index_adjustments_on_iva_id                                  (iva_id)
#  index_adjustments_on_target_type_and_target_id               (target_type,target_id)
#  index_adjustments_on_user_id                                 (user_id)
#  index_adjustments_on_user_id_and_adjustment_type_and_active  (user_id,adjustment_type,active)
#
# Foreign Keys
#
#  fk_rails_...  (iva_id => ivas.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :adjustment do
    association :user
    association :target, factory: :client
    adjustment_type  { 'discount' }
    calculation_type { 'percentage' }
    amount           { 10.0 }
    active           { true }
    start_date       { Date.current }
    end_date         { nil }
  end
end
