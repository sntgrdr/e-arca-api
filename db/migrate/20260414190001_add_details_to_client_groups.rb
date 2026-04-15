class AddDetailsToClientGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :client_groups, :details, :text
  end
end
