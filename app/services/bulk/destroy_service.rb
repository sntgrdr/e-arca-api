module Bulk
  class DestroyService
    def initialize(scope:, ids:)
      @scope = scope
      @ids = ids
    end

    def call
      records = @scope.where(id: @ids)
      deleted_count = 0
      skipped = []

      records.each do |record|
        reason = skip_reason(record)
        if reason.nil?
          record.destroy!
          deleted_count += 1
        else
          skipped << { id: record.id, identifier: build_identifier(record), reason: reason }
        end
      end

      { deleted: deleted_count, skipped: skipped.size, skipped_reasons: skipped }
    end

    private

    def skip_reason(_record)
      raise NotImplementedError, "#{self.class}#skip_reason must be implemented"
    end

    def build_identifier(_record)
      raise NotImplementedError, "#{self.class}#build_identifier must be implemented"
    end
  end
end
