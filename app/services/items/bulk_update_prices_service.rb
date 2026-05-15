module Items
  class BulkUpdatePricesService
    MAX_ITEMS = 100

    def initialize(scope:, items_data:)
      @scope      = scope
      @items_data = items_data
    end

    def call
      return error("No items provided")                                                         if @items_data.blank?
      return error("Cannot exceed #{MAX_ITEMS} items (received #{@items_data.size})")           if @items_data.size > MAX_ITEMS
      return error("All prices must be greater than 0")                                         if any_invalid_price?

      items = @scope.includes(:iva).where(id: ids)
      return error("No valid items found")                                                      if items.empty?

      updated = update_items(items)
      { success: true, items: updated }
    rescue ActiveRecord::RecordInvalid => e
      error(e.message)
    end

    private

    def ids
      @items_data.map { |d| d[:id].to_i }
    end

    def any_invalid_price?
      @items_data.any? { |d| d[:price].to_f <= 0 }
    end

    def update_items(items)
      updated = []
      ActiveRecord::Base.transaction do
        @items_data.each do |item_data|
          item = items.find { |i| i.id == item_data[:id].to_i }
          next unless item
          item.update!(price: item_data[:price])
          updated << item
        end
      end
      updated
    end

    def error(msg)
      { success: false, error: msg }
    end
  end
end
