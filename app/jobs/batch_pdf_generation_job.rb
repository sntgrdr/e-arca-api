class BatchPdfGenerationJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::ConnectionTimeoutError,
           wait: :polynomially_longer,
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(batch_invoice_process_id)
    batch = BatchInvoiceProcess.find(batch_invoice_process_id)

    zip_data = Invoices::BatchPdfZipGeneratorService.new(batch_process: batch).call

    batch.pdf_zip.attach(
      io: StringIO.new(zip_data),
      filename: "facturas_lote_#{batch.id}.zip",
      content_type: 'application/zip'
    )

    batch.update!(pdf_generated: true)
  rescue StandardError => e
    Rails.logger.error("[BatchPdfGenerationJob] batch_id=#{batch_invoice_process_id} #{e.class}: #{e.message}")
    raise
  end
end
