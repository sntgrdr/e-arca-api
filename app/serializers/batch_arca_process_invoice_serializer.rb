class BatchArcaProcessInvoiceSerializer < ActiveModel::Serializer
  attributes :id, :number, :invoice_type, :total_price,
             :arca_status, :cae, :afip_invoice_number, :afip_authorized_at, :arca_error,
             :client_name

  # Callers must preload invoice.client to avoid N+1 (see BatchArcaProcessDetailSerializer).
  def number
    invoice.number
  end

  def invoice_type
    invoice.invoice_type
  end

  def total_price
    invoice.total_price
  end

  def cae
    invoice.cae
  end

  def afip_invoice_number
    invoice.afip_invoice_number
  end

  def afip_authorized_at
    invoice.afip_authorized_at
  end

  def arca_error
    object.arca_error
  end

  def client_name
    invoice.client&.legal_name
  end

  private

  def invoice
    object.invoice
  end
end
