class AddUniqueIndexOnItemsNamePerUser < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :items, [ :user_id, :name ], unique: true,
              algorithm: :concurrently,
              name: "index_items_on_user_id_and_name"
  end
end
