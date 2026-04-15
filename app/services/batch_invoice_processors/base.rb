# Shared invoice-creation and finalization logic for all batch processor strategies.
# Subclasses implement #run.
module BatchInvoiceProcessors
  class Base
    private

    # Creates one ClientInvoice for the given client inside an advisory-locked transaction.
    # Yields inside the transaction if a block is given — use this to atomically
    # increment counters together with the invoice commit (prevents over-generation
    # on job retry when the counter update is the operation that failed).
    def create_invoice(batch, client, items)
      ApplicationRecord.transaction do
        ApplicationRecord.connection.exec_query(
          "SELECT pg_advisory_xact_lock($1, $2)",
          "advisory_lock",
          [ batch.user_id, batch.sell_point_id ]
        )

        number      = ClientInvoice.current_number(batch.user_id, batch.sell_point_id, batch.invoice_type)
        total_price = price_sum(items)
        lines       = build_lines(items, batch.user_id)

        ClientInvoice.create!(
          number:                   number,
          date:                     batch.date,
          period:                   batch.period,
          invoice_type:             batch.invoice_type,
          sell_point_id:            batch.sell_point_id,
          user_id:                  batch.user_id,
          client_id:                client.id,
          batch_invoice_process_id: batch.id,
          total_price:              total_price,
          lines_attributes:         lines
        )

        yield if block_given?
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

    def price_sum(items)
      items.sum do |item|
        iva_percentage = item.iva&.percentage || 0
        (item.price * (1 + (iva_percentage / 100.0))).round(4)
      end
    end

    def build_lines(items, user_id)
      items.map do |item|
        iva_percentage = item.iva&.percentage || 0
        gross_price    = (item.price * (1 + (iva_percentage / 100.0))).round(4)
        {
          item_id:     item.id,
          iva_id:      item.iva_id,
          description: item.name,
          quantity:    1,
          unit_price:  item.price,
          final_price: gross_price,
          user_id:     user_id
        }
      end
    end
  end
end
