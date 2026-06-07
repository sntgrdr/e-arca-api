class AddIvaToAdjustments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :adjustments, :iva, null: true, index: { algorithm: :concurrently }
  end
end
