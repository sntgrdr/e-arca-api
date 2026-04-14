class HardDeleteNonCaeDiscardedInvoices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    # Hard-delete soft-deleted invoices that were never authorized by AFIP.
    # These records are safe to remove: they were never reported to ARCA
    # and their numbers can be reused going forward.
    safety_assured do
      execute <<~SQL
        DELETE FROM invoices
        WHERE discarded_at IS NOT NULL
          AND cae IS NULL
      SQL
    end

    # Revert to a full unique index now that discarded-without-CAE records
    # no longer exist in the database.
    remove_index :invoices, name: "idx_unique_sellpoint_type_number"
    add_index :invoices,
              [ :sell_point_id, :type, :number ],
              name: "idx_unique_sellpoint_type_number",
              unique: true,
              algorithm: :concurrently
  end

  def down
    remove_index :invoices, name: "idx_unique_sellpoint_type_number"
    add_index :invoices,
              [ :sell_point_id, :type, :number ],
              name: "idx_unique_sellpoint_type_number",
              unique: true,
              where: "discarded_at IS NULL OR cae IS NOT NULL",
              algorithm: :concurrently
  end
end
