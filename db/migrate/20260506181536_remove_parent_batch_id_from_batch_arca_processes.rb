class RemoveParentBatchIdFromBatchArcaProcesses < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_reference :batch_arca_processes, :parent_batch, foreign_key: { to_table: :batch_arca_processes }, index: true
    end
  end
end
