module Filters
  class ItemsFilterService < BaseFilterService
    def call
      result = scope.includes(:iva, :item_group)
      result = filter_by_code(result)
      result = filter_by_name(result)
      result = filter_by_iva_id(result)
      result = filter_by_item_group_id(result)
      result = filter_by_price_from(result)
      result = filter_by_price_to(result)
      result
    rescue StandardError => e
      Rails.logger.error("ItemsFilterService error: #{e.message}")
      scope.includes(:iva)
    end

    private

    def filter_by_code(result)
      value = stripped_param(:code)
      return result if value.blank?

      result.where("items.code ILIKE ?", "%#{sanitize(value)}%")
    end

    def filter_by_name(result)
      value = stripped_param(:name)
      return result if value.blank?

      result.where("items.name ILIKE ?", "%#{sanitize(value)}%")
    end

    def filter_by_iva_id(result)
      values = array_param(:iva_id)
      return result if values.empty?

      result.where(iva_id: values)
    end

    def filter_by_item_group_id(result)
      values = array_param(:item_group_id)
      return result if values.empty?

      result.where(item_group_id: values)
    end

    def filter_by_price_from(result)
      value = stripped_param(:price_from)
      return result if value.blank?

      result.where("items.price >= ?", value.to_f)
    end

    def filter_by_price_to(result)
      value = stripped_param(:price_to)
      return result if value.blank?

      result.where("items.price <= ?", value.to_f)
    end
  end
end
