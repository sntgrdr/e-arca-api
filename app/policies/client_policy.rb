class ClientPolicy < ApplicationPolicy
  def search?
    true
  end

  def deactivate?
    owner?
  end

  def reactivate?
    owner?
  end

  def bulk_deactivate?
    true
  end

  def bulk_reactivate?
    true
  end

  def destroy?
    owner? && !record[:final_client]
  end
end
