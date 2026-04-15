class AddProcessTypeAndQuantityToBatchInvoiceProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :batch_invoice_processes, :process_type, :string, null: false, default: "per_client"
    add_column :batch_invoice_processes, :quantity, :integer
    add_column :batch_invoice_processes, :invoice_type, :string

    # item_id is NOT NULL in the schema but optional in the model.
    # FinalConsumer batches don't use item_id — make it nullable to match reality.
    change_column_null :batch_invoice_processes, :item_id, true
  end
end
