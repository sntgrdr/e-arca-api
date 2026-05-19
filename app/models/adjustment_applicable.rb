class AdjustmentApplicable < ApplicationRecord
  belongs_to :adjustment
  belongs_to :applicable, polymorphic: true

  validates :applicable_type, inclusion: { in: %w[Item ItemGroup] }
  validates :adjustment_id, uniqueness: {
    scope: [:applicable_type, :applicable_id],
    message: "ya existe un ajuste para este item/grupo"
  }
end
