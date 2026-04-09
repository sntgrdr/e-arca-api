class AddDiscardedAtToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :discarded_at, :datetime
    add_index :invoices, :discarded_at
  end
end
