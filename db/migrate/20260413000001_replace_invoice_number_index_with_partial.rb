class ReplaceInvoiceNumberIndexWithPartial < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :invoices, name: "idx_unique_sellpoint_type_number"
    add_index :invoices,
              [ :sell_point_id, :type, :number ],
              name: "idx_unique_sellpoint_type_number",
              unique: true,
              where: "discarded_at IS NULL OR cae IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :invoices, name: "idx_unique_sellpoint_type_number"
    add_index :invoices,
              [ :sell_point_id, :type, :number ],
              name: "idx_unique_sellpoint_type_number",
              unique: true,
              algorithm: :concurrently
  end
end
