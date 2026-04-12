require "zlib"

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

    batch.update!(status: :processing)

    clients = batch.resolved_clients
    batch.update!(total_invoices: clients.count)

    clients.find_each do |client|
      next if ClientInvoice.exists?(batch_invoice_process_id: batch.id, client_id: client.id)

      begin
        create_invoice_for_client(batch, client)
        batch.increment!(:processed_invoices)
      rescue StandardError => e
        Rails.logger.error(
          "[BulkInvoiceCreationJob] batch_id=#{batch.id} client_id=#{client.id} #{e.class}: #{e.message}"
        )
        batch.increment!(:failed_invoices)
        batch.update!(
          error_details: batch.error_details + [ {
            client_id: client.id,
            client_name: client.legal_name,
            error: "#{e.class}: #{e.message}"
          } ]
        )
      end
    end

    if batch.failed_invoices > 0
      batch.update!(
        status: :completed,
        error_message: "#{batch.processed_invoices} creadas, #{batch.failed_invoices} fallidas"
      )
    else
      batch.update!(status: :completed)
    end
  rescue StandardError => e
    Rails.logger.error("[BulkInvoiceCreationJob] batch_id=#{batch_invoice_process_id} FATAL: #{e.class}: #{e.message}")
    BatchInvoiceProcess.find_by(id: batch_invoice_process_id)
                       &.update!(status: :failed, error_message: e.message)
    raise
  end

  private

  # Uses a PostgreSQL advisory lock to prevent two concurrent jobs for the same
  # (user, sell_point, invoice_type) from racing on the next invoice number.
  def create_invoice_for_client(batch, client)
    items    = batch.resolved_items
    lock_key = Zlib.crc32("invoice_number_#{batch.user_id}_#{batch.sell_point_id}_C")

    ApplicationRecord.transaction do
      ApplicationRecord.connection.execute(
        "SELECT pg_advisory_xact_lock(#{lock_key})"
      )

      number      = ClientInvoice.current_number(batch.user_id, batch.sell_point_id, "C")
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
        invoice_type:             "C",
        sell_point_id:            batch.sell_point_id,
        user_id:                  batch.user_id,
        client_id:                client.id,
        batch_invoice_process_id: batch.id,
        total_price:              total_price,
        lines_attributes:         lines
      )
    end
  end
end
