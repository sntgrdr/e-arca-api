class ChangeStartDateNotNullOnAdjustments < ActiveRecord::Migration[8.1]
  def up
    Adjustment.where(start_date: nil).update_all(start_date: Date.current)
    add_check_constraint :adjustments, "start_date IS NOT NULL",
      name: "adjustments_start_date_null", validate: false
  end

  def down
    remove_check_constraint :adjustments, name: "adjustments_start_date_null"
  end
end
