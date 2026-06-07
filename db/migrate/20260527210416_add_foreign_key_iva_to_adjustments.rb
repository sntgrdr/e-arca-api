class AddForeignKeyIvaToAdjustments < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :adjustments, :ivas, validate: false
  end
end
