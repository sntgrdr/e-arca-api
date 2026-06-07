# == Schema Information
#
# Table name: adjustment_applicables
#
#  id              :bigint           not null, primary key
#  applicable_type :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  adjustment_id   :bigint           not null
#  applicable_id   :bigint           not null
#
# Indexes
#
#  idx_adjustment_applicables_unique                (adjustment_id,applicable_type,applicable_id) UNIQUE
#  idx_on_applicable_type_applicable_id_29ef713aba  (applicable_type,applicable_id)
#  index_adjustment_applicables_on_adjustment_id    (adjustment_id)
#
# Foreign Keys
#
#  fk_rails_...  (adjustment_id => adjustments.id)
#
class AdjustmentApplicable < ApplicationRecord
  belongs_to :adjustment
  belongs_to :applicable, polymorphic: true

  validates :applicable_type, inclusion: { in: %w[Item ItemGroup] }
  validates :adjustment_id, uniqueness: {
    scope: [ :applicable_type, :applicable_id ],
    message: "ya existe un ajuste para este item/grupo"
  }
end
