class CommentPolicy < ApplicationPolicy
  def create?  = true
  def destroy? = owner?
end
