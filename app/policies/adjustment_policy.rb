class AdjustmentPolicy < ApplicationPolicy
  def deactivate? = owner?
  def reactivate? = owner?
  def resolve?    = true

  class Scope < Scope
    def resolve
      scope.kept.where(user_id: user.id)
    end
  end
end
