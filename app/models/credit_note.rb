class CreditNote < Invoice
  has_paper_trail

  include Reportable

  belongs_to :client_invoice,
           class_name: "ClientInvoice",
           optional: false

  def afip_code
    case invoice_type
    when "A", "EA" then "3"
    when "B", "EB" then "8"
    when "C", "EC" then "13"
    end
  end

  def associated_cbte_tipo
    client_invoice.afip_code
  end

  def associated_cbte_punto_vta
    client_invoice.sell_point.number
  end

  def associated_cbte_numero
    client_invoice.number
  end

  def has_associated_cbte?
    true
  end
end
