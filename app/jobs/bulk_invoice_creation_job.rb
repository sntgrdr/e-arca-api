class BulkInvoiceCreationJob < ApplicationJob
  queue_as :default

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
      create_invoice_for_client(batch, client)
      batch.increment!(:processed_invoices)
    end

    batch.update!(status: :completed)
  rescue => e
    batch = BatchInvoiceProcess.find(batch_invoice_process_id)
    batch.update!(status: :failed, error_message: e.message)
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
