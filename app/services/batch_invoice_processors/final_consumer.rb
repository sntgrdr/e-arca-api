module BatchInvoiceProcessors
  class FinalConsumer < Base
    class MissingFinalConsumerClient < StandardError; end

    def initialize(batch)
      @batch = batch
    end

    def run
      batch = @batch
      batch.update!(status: :processing) unless batch.processing?

      final_client = Client.find_by(user_id: batch.user_id, final_client: true)
      unless final_client
        raise MissingFinalConsumerClient,
              "No final consumer client found for user #{batch.user_id}. Run ProvisionDefaultUserResourcesJob first."
      end

      items = batch.resolved_items
      batch.update!(total_invoices: batch.quantity)

      # Use DB count for remaining to stay correct on job retry.
      # processed_invoices is incremented inside the transaction so it only advances
      # when the invoice is committed — both operations are atomic.
      remaining = batch.quantity - batch.processed_invoices
      error_log = []

      remaining.times do
        begin
          create_invoice(batch, final_client, items) { batch.increment!(:processed_invoices) }
        rescue StandardError => e
          Rails.logger.error(
            "[BatchInvoiceProcessors::FinalConsumer] batch_id=#{batch.id} #{e.class}: #{e.message}"
          )
          batch.increment!(:failed_invoices)
          error_log << { error: "#{e.class}: #{e.message}" }
        end
      end

      finalize(batch, error_log)
    end
  end
end
