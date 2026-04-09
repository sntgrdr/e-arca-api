class CreditNotePolicy < ApplicationPolicy
  def send_to_arca? = owner?
  def next_number?  = true
end
