class BulkInvoiceCreationJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::ConnectionTimeoutError,
           ActiveRecord::Deadlocked,
           wait: :polynomially_longer,
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(batch_invoice_process_id)
    batch = BatchInvoiceProcess
      .includes(:batch_invoice_process_items, :batch_items,
                :batch_invoice_process_clients, :selected_clients)
      .find(batch_invoice_process_id)

    batch.processor.run
  rescue StandardError => e
    Rails.logger.error("[BulkInvoiceCreationJob] batch_id=#{batch_invoice_process_id} FATAL: #{e.class}: #{e.message}")
    BatchInvoiceProcess.find_by(id: batch_invoice_process_id)
                       &.update!(status: :failed, error_message: e.message)
    raise
  end
end
