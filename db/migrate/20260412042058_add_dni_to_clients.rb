class AddDniToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :dni, :string
  end
end
