module BatchInvoiceProcessors
  class FinalConsumer
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

      error_log = []
      remaining  = batch.quantity - batch.processed_invoices

      remaining.times do
        begin
          create_invoice(batch, final_client, items)
          batch.increment!(:processed_invoices)
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

    private

    def create_invoice(batch, final_client, items)
      ApplicationRecord.transaction do
        ApplicationRecord.connection.exec_query(
          "SELECT pg_advisory_xact_lock($1, $2)",
          "advisory_lock",
          [ batch.user_id, batch.sell_point_id ]
        )

        number      = ClientInvoice.current_number(batch.user_id, batch.sell_point_id, batch.invoice_type)
        total_price = items.sum do |item|
          iva_percentage = item.iva&.percentage || 0
          (item.price * (1 + (iva_percentage / 100.0))).round(4)
        end

        lines = items.map do |item|
          iva_percentage = item.iva&.percentage || 0
          gross_price    = (item.price * (1 + (iva_percentage / 100.0))).round(4)
          {
            item_id:     item.id,
            iva_id:      item.iva_id,
            description: item.name,
            quantity:    1,
            unit_price:  item.price,
            final_price: gross_price,
            user_id:     batch.user_id
          }
        end

        ClientInvoice.create!(
          number:                   number,
          date:                     batch.date,
          period:                   batch.period,
          invoice_type:             batch.invoice_type,
          sell_point_id:            batch.sell_point_id,
          user_id:                  batch.user_id,
          client_id:                final_client.id,
          batch_invoice_process_id: batch.id,
          total_price:              total_price,
          lines_attributes:         lines
        )
      end
    end

    def finalize(batch, error_log)
      if error_log.any?
        batch.reload
        batch.update!(
          status:        :completed,
          error_message: "#{batch.processed_invoices} creadas, #{batch.failed_invoices} fallidas",
          error_details: error_log
        )
      else
        batch.update!(status: :completed)
      end
    end
  end
end
