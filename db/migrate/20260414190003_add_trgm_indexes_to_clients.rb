class AddTrgmIndexesToClients < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    enable_extension "pg_trgm"

    add_index :clients, :legal_name, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    add_index :clients, :name,       using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
  end

  def down
    remove_index :clients, name: :index_clients_on_legal_name
    remove_index :clients, name: :index_clients_on_name
  end
end
