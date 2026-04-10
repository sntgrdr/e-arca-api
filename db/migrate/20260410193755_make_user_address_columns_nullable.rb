class MakeUserAddressColumnsNullable < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      change_column :users, :address, :string, null: true, default: nil
      change_column :users, :city, :string, null: true, default: nil
      change_column :users, :state, :string, null: true, default: nil
      change_column :users, :country, :string, null: true, default: nil
      change_column :users, :zip_code, :string, null: true, default: nil
    end
  end

  def down
    safety_assured do
      change_column :users, :address, :string, null: false, default: ""
      change_column :users, :city, :string, null: false, default: ""
      change_column :users, :state, :string, null: false, default: ""
      change_column :users, :country, :string, null: false, default: ""
      change_column :users, :zip_code, :string, null: false, default: ""
    end
  end
end
