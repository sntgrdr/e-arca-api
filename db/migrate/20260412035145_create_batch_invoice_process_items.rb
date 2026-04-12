class CreateBatchInvoiceProcessItems < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_invoice_process_items do |t|
      t.references :batch_invoice_process, null: false, foreign_key: true
      t.references :item,                  null: false, foreign_key: true
      t.integer    :position,              null: false, default: 0

      t.timestamps
    end

    add_index :batch_invoice_process_items,
              [ :batch_invoice_process_id, :item_id ],
              unique: true,
              name: "index_bip_items_on_bip_id_and_item_id"
  end
end
