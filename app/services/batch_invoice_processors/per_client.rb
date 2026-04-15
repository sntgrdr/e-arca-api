module BatchInvoiceProcessors
  class PerClient < Base
    def initialize(batch)
      @batch = batch
    end

    def run
      batch = @batch
      batch.update!(status: :processing) unless batch.processing?

      clients = batch.resolved_clients
      batch.update!(total_invoices: clients.count)

      items     = batch.resolved_items  # load once outside the loop — avoids N+1 per client
      error_log = []

      clients.each do |client|
        # Idempotency: skip clients that already have an invoice for this batch.
        next if ClientInvoice.exists?(batch_invoice_process_id: batch.id, client_id: client.id)

        begin
          create_invoice(batch, client, items) { batch.increment!(:processed_invoices) }
        rescue StandardError => e
          Rails.logger.error(
            "[BatchInvoiceProcessors::PerClient] batch_id=#{batch.id} client_id=#{client.id} #{e.class}: #{e.message}"
          )
          batch.increment!(:failed_invoices)
          error_log << { client_id: client.id, client_name: client.legal_name, error: "#{e.class}: #{e.message}" }
        end
      end

      finalize(batch, error_log)
    end
  end
end
