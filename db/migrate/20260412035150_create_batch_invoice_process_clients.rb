class CreateBatchInvoiceProcessClients < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_invoice_process_clients do |t|
      t.references :batch_invoice_process, null: false, foreign_key: true
      t.references :client,                null: false, foreign_key: true

      t.timestamps
    end

    add_index :batch_invoice_process_clients,
              [ :batch_invoice_process_id, :client_id ],
              unique: true,
              name: "index_bip_clients_on_bip_id_and_client_id"
  end
end
