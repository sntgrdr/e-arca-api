class ClientInvoice < Invoice
  has_paper_trail

  include Reportable

  belongs_to :batch_invoice_process, optional: true

  has_many :credit_notes,
           foreign_key: :client_invoice_id,
           dependent: :nullify

  validates :total_price, numericality: { greater_than: 0 }

  def afip_code
    case invoice_type
    when "A", "EA" then "1"
    when "B", "EB" then "6"
    when "C", "EC" then "11"
    end
  end
end
