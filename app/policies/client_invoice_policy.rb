class ClientInvoicePolicy < ApplicationPolicy
  def send_to_arca? = owner?
  def download_pdf?  = owner?
  def next_number?  = true
end
