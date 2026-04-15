class BatchInvoiceProcessDetailSerializer < ActiveModel::Serializer
  INVOICE_CAP = 200

  attributes :id, :status, :process_type, :date, :period, :total_invoices,
             :processed_invoices, :failed_invoices, :pdf_generated,
             :error_message, :error_details, :client_group_id, :item_id,
             :sell_point_id, :sell_point, :client_group, :invoice_type, :quantity,
             :created_at, :updated_at, :items,
             :client_invoices, :client_invoices_capped, :client_invoices_total,
             :client_name

  def sell_point
    return nil unless object.sell_point
    { id: object.sell_point.id, number: object.sell_point.number }
  end

  def items
    object.resolved_items.map do |i|
      { id: i.id, name: i.name, code: i.code }
    end
  end

  def client_group
    return nil unless object.client_group
    { id: object.client_group.id, name: object.client_group.name }
  end

  def client_invoices
    @client_invoices ||= object.client_invoices
                               .includes(:client, :sell_point)
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
    client_invoices_total >= INVOICE_CAP
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

  def client_name
    object.client_invoices.includes(:client).order(created_at: :asc).first&.client&.legal_name
  end
end
