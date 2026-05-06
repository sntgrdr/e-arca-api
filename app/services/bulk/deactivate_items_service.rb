module Bulk
  class DeactivateItemsService
    def initialize(scope:, ids:)
      @scope = scope
      @ids = ids
    end

    def call
      updated = @scope.where(id: @ids).update_all(active: false)
      { updated: updated }
    end
  end
end
