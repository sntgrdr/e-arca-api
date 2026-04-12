class BatchInvoiceProcessDetailSerializer < ActiveModel::Serializer
  INVOICE_CAP = 200

  attributes :id, :status, :date, :period, :total_invoices,
             :processed_invoices, :failed_invoices, :pdf_generated,
             :error_message, :error_details, :client_group_id, :item_id,
             :sell_point_id, :sell_point, :created_at, :updated_at,
             :items,
             :client_invoices, :client_invoices_capped, :client_invoices_total

  def sell_point
    return nil unless object.sell_point
    { id: object.sell_point.id, number: object.sell_point.number }
  end

  def items
    object.resolved_items.map do |i|
      { id: i.id, name: i.name, code: i.code }
    end
  end

  def client_invoices
    @client_invoices ||= object.client_invoices
                               .includes(:client)
                               .order(created_at: :asc)
                               .limit(INVOICE_CAP)
                               .map { |inv| BatchClientInvoiceSerializer.new(inv).attributes }
  end

  def client_invoices_total
    @client_invoices_total ||=
      if client_invoices.size < INVOICE_CAP
        client_invoices.size
      else
        object.client_invoices.count
      end
  end

  def client_invoices_capped
    client_invoices_total > INVOICE_CAP
  end

  def error_details
    object.error_details if object.failed?
  end

  # Remove error_details key entirely when not failed (not just null)
  def attributes(*args)
    data = super
    data.delete(:error_details) unless object.failed?
    data
  end
end
