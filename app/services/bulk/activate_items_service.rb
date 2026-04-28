module Bulk
  class ActivateItemsService
    def initialize(scope:, ids:)
      @scope = scope
      @ids = ids
    end

    def call
      updated = @scope.where(id: @ids).update_all(active: true)
      { updated: updated }
    end
  end
end
