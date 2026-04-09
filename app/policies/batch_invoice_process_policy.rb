class BatchInvoiceProcessPolicy < ApplicationPolicy
  def generate_pdfs?  = owner?
  def download_pdfs?  = owner?
  def last_invoice_date? = true
end
