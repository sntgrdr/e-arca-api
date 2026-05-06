class CreateBatchArcaProcesses < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_arca_processes do |t|
      t.references :user,       null: false, foreign_key: true
      t.references :sell_point, null: false, foreign_key: true
      t.string  :invoice_class,      null: false
      t.string  :invoice_type,       null: false
      t.string  :status,             null: false, default: "pending"
      t.integer :total_invoices,     null: false, default: 0
      t.integer :processed_invoices, null: false, default: 0
      t.integer :failed_invoices,    null: false, default: 0
      t.text    :error_message
      t.bigint  :parent_batch_id
      t.string  :idempotency_key

      t.timestamps
    end

    add_index :batch_arca_processes, :parent_batch_id
    add_index :batch_arca_processes, :status
    add_index :batch_arca_processes, [ :user_id, :idempotency_key ],
              unique: true,
              where: "idempotency_key IS NOT NULL"
    # safety_assured: new table has no existing rows; foreign key cannot block writes
    safety_assured do
      add_foreign_key :batch_arca_processes, :batch_arca_processes,
                      column: :parent_batch_id
    end
  end
end
