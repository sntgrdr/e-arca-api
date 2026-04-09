class AddAfipStatusToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :afip_status, :string, default: "draft", null: false
    add_index :invoices, :afip_status

    # Backfill existing records
    execute <<-SQL
      UPDATE invoices SET afip_status = 'authorized' WHERE cae IS NOT NULL;
      UPDATE invoices SET afip_status = 'rejected' WHERE afip_result = 'R' AND cae IS NULL;
    SQL
  end

  def down
    remove_column :invoices, :afip_status
  end
end
