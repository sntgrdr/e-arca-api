class CreateAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :adjustments do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string  :adjustment_type, null: false
      t.string  :calculation_type, null: false
      t.decimal :amount, precision: 15, scale: 4, null: false
      t.string  :target_type, null: false
      t.bigint  :target_id, null: false
      t.date    :start_date
      t.date    :end_date
      t.boolean :active, null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :adjustments, :deleted_at
    add_index :adjustments, [:target_type, :target_id]
    add_index :adjustments, [:user_id, :adjustment_type, :active]
  end
end
