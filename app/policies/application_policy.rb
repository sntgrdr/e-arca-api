class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?    = true
  def show?     = owner?
  def create?   = true
  def update?   = owner?
  def destroy?  = owner?

  private

  def owner?
    record.user_id == user.id
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      base = scope.respond_to?(:kept) ? scope.kept : scope
      base.where(user_id: user.id)
    end
  end
end
