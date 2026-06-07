class AddAdjustmentsEnabledToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :adjustments_enabled, :boolean, default: false
    add_check_constraint :users, "adjustments_enabled IS NOT NULL",
      name: "users_adjustments_enabled_null", validate: false
  end

  def down
    remove_check_constraint :users, name: "users_adjustments_enabled_null"
    remove_column :users, :adjustments_enabled
  end
end
