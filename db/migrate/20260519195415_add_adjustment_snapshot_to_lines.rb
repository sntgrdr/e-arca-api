class AddAdjustmentSnapshotToLines < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :lines, :line_type,                   :string, null: false, default: 'item'
    add_column :lines, :original_price,              :decimal, precision: 15, scale: 4
    add_column :lines, :calculated_price,            :decimal, precision: 15, scale: 4
    add_column :lines, :applied_adjustment_id,       :bigint
    add_column :lines, :applied_adjustment_type,     :string
    add_column :lines, :applied_adjustment_amount,   :decimal, precision: 15, scale: 4

    add_index :lines, :applied_adjustment_id, algorithm: :concurrently
    add_index :lines, :line_type, algorithm: :concurrently
  end
end
