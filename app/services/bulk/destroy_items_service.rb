module Bulk
  class DestroyItemsService < DestroyService
    private

    def skip_reason(record)
      "referenced_in_line" if Line.where(item_id: record.id).exists?
    end

    def build_identifier(record)
      "#{record.name} — #{record.code}"
    end
  end
end
