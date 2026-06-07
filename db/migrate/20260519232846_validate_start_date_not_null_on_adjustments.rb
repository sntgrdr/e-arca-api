class ValidateStartDateNotNullOnAdjustments < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :adjustments, name: "adjustments_start_date_null"
    change_column_null :adjustments, :start_date, false
    remove_check_constraint :adjustments, name: "adjustments_start_date_null"
  end

  def down
    add_check_constraint :adjustments, "start_date IS NOT NULL",
      name: "adjustments_start_date_null", validate: false
    change_column_null :adjustments, :start_date, true
  end
end
