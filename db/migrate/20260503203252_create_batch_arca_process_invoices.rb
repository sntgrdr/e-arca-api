class CreateBatchArcaProcessInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_arca_process_invoices do |t|
      t.references :batch_arca_process, null: false, foreign_key: true
      t.references :invoice,            null: false, foreign_key: true
      t.string  :arca_status,  null: false, default: "pending"
      t.text    :arca_error
      t.datetime :processed_at

      t.timestamps
    end

    add_index :batch_arca_process_invoices,
              [ :batch_arca_process_id, :invoice_id ],
              unique: true,
              name: "idx_batch_arca_invoices_uniqueness"

    add_index :batch_arca_process_invoices, :arca_status
  end
end
