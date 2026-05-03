class BatchArcaProcessJob < ApplicationJob
  queue_as :default

  def perform(batch_arca_process_id)
    # Placeholder — full implementation in Task 9
  end
end
