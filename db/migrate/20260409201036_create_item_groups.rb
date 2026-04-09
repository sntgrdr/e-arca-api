class CreateItemGroups < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    create_table :item_groups do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.bigint :user_id, null: false

      t.timestamps
    end

    add_index :item_groups, :user_id, algorithm: :concurrently
    add_index :item_groups, %i[user_id name], unique: true, algorithm: :concurrently

    safety_assured do
      add_foreign_key :item_groups, :users
    end

    add_column :items, :item_group_id, :bigint, null: true
    add_index :items, :item_group_id, algorithm: :concurrently

    safety_assured do
      add_foreign_key :items, :item_groups
    end
  end

  def down
    remove_foreign_key :items, :item_groups
    remove_column :items, :item_group_id

    drop_table :item_groups
  end
end
