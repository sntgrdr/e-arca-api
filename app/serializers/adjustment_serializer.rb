class AdjustmentSerializer < ActiveModel::Serializer
  attributes :id, :adjustment_type, :calculation_type, :amount,
             :target_type, :target_id, :start_date, :end_date, :active,
             :created_at

  attribute :applicable_ids do
    object.adjustment_applicables.map(&:applicable_id)
  end

  attribute :applicable_type do
    object.adjustment_applicables.first&.applicable_type
  end

  attribute :applicable_names do
    object.adjustment_applicables.filter_map do |ap|
      ap.applicable&.try(:name)
    end
  end

  attribute :target_name do
    object.target&.try(:name) || object.target&.try(:legal_name)
  end
end
