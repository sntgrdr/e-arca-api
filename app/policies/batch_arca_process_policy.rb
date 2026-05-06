class BatchArcaProcessPolicy < ApplicationPolicy
  def index?   = true
  def show?    = record.user_id == user.id
  def create?  = true
  def retry?   = record.user_id == user.id && record.retryable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
