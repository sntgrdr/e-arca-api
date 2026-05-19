class CreateAdjustmentApplicables < ActiveRecord::Migration[8.1]
  def change
    create_table :adjustment_applicables do |t|
      t.references :adjustment, null: false, foreign_key: true, index: true
      t.string :applicable_type, null: false
      t.bigint :applicable_id,   null: false

      t.timestamps
    end

    add_index :adjustment_applicables, [:applicable_type, :applicable_id]
    add_index :adjustment_applicables,
              [:adjustment_id, :applicable_type, :applicable_id],
              unique: true,
              name: "idx_adjustment_applicables_unique"
  end
end
