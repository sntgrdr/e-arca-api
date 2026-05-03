class BatchArcaProcessJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(batch_arca_process_id)
    batch = nil
    batch = BatchArcaProcess.find(batch_arca_process_id)

    return if batch.processing? || batch.completed?

    acquired = ApplicationRecord.connection.exec_query(
      "SELECT pg_try_advisory_lock($1, $2)",
      "arca_advisory_try_lock",
      [ batch.user_id, batch.sell_point_id ]
    ).first["pg_try_advisory_lock"]

    unless acquired
      batch.update!(
        status:        :failed,
        error_message: "Another batch is already processing this sell point. Please retry."
      )
      return
    end

    BatchArca::ProcessorService.new(batch).call
  ensure
    if batch
      ApplicationRecord.connection.exec_query(
        "SELECT pg_advisory_unlock($1, $2)",
        "arca_advisory_unlock",
        [ batch.user_id, batch.sell_point_id ]
      ) rescue nil
    end
  end
end
