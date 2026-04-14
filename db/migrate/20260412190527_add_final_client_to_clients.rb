class AddFinalClientToClients < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :clients, :final_client, :boolean, default: false, null: false
    add_index :clients, [ :user_id, :final_client ],
              unique: true,
              where: "final_client = TRUE",
              name: "index_clients_on_user_id_final_client_unique",
              algorithm: :concurrently
  end
end
