class AddDniToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :users, :dni, :string
    add_index :users, :dni, unique: true, algorithm: :concurrently

    User.find_each do |user|
      next if user.legal_number.blank?

      digits = user.legal_number.gsub("-", "")
      user.update_column(:dni, digits[2..9]) if digits.length == 11
    end
  end

  def down
    remove_column :users, :dni
  end
end
