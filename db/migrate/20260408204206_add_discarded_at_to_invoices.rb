class AddDiscardedAtToInvoices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :invoices, :discarded_at, :datetime
    add_index :invoices, :discarded_at, algorithm: :concurrently
  end
end
