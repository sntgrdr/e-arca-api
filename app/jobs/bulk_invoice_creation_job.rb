class BulkInvoiceCreationJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::ConnectionTimeoutError,
           ActiveRecord::Deadlocked,
           wait: :polynomially_longer,
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(batch_invoice_process_id)
    batch = BatchInvoiceProcess.find(batch_invoice_process_id)
    batch.update!(status: :processing)

    clients = if batch.client_group_id.present?
                batch.client_group.clients.where(active: true)
              else
                Client.all_my_clients(batch.user_id)
              end

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
          error_details: batch.error_details + [{
            client_id: client.id,
            client_name: client.legal_name,
            error: "#{e.class}: #{e.message}"
          }]
        )
      end
    end

    if batch.failed_invoices > 0
      batch.update!(
        status: :completed,
        error_message: "#{batch.processed_invoices} created, #{batch.failed_invoices} failed"
      )
    else
      batch.update!(status: :completed)
    end
  rescue StandardError => e
    Rails.logger.error("[BulkInvoiceCreationJob] batch_id=#{batch_invoice_process_id} FATAL: #{e.class}: #{e.message}")
    batch = BatchInvoiceProcess.find_by(id: batch_invoice_process_id)
    batch&.update!(status: :failed, error_message: e.message)
    raise
  end

  private

  def create_invoice_for_client(batch, client)
    number = ClientInvoice.current_number(batch.user_id, batch.sell_point_id)
    item = batch.item
    iva_percentage = item.iva&.percentage || 0
    gross_price = (item.price * (1 + (iva_percentage / 100.0))).round(4)

    ClientInvoice.create!(
      number: number,
      date: batch.date,
      period: batch.period,
      invoice_type: 'C',
      sell_point_id: batch.sell_point_id,
      user_id: batch.user_id,
      client_id: client.id,
      batch_invoice_process_id: batch.id,
      total_price: gross_price,
      lines_attributes: [
        {
          item_id: item.id,
          iva_id: item.iva_id,
          description: item.name,
          quantity: 1,
          unit_price: item.price,
          final_price: gross_price,
          user_id: batch.user_id
        }
      ]
    )
  end
end
