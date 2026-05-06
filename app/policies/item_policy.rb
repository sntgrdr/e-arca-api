class ItemPolicy < ApplicationPolicy
  def autocomplete?    = true
  def bulk_destroy?    = true
  def bulk_activate?   = true
  def bulk_deactivate? = true
end
