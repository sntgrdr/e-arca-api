class AddDetailsToItemGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :item_groups, :details, :text
  end
end
