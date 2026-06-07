class ValidateAdjustmentsEnabledNotNullOnUsers < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :users, name: "users_adjustments_enabled_null"
    change_column_null :users, :adjustments_enabled, false
    remove_check_constraint :users, name: "users_adjustments_enabled_null"
  end

  def down
    add_check_constraint :users, "adjustments_enabled IS NOT NULL",
      name: "users_adjustments_enabled_null", validate: false
    change_column_null :users, :adjustments_enabled, true
  end
end
