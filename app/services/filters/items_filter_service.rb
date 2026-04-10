module Filters
  class ItemsFilterService
    def initialize(params, scope)
      @params = params
      @scope = scope
    end

    def call
      result = scope.includes(:iva)
      result = filter_by_code(result)
      result = filter_by_name(result)
      result = filter_by_iva_id(result)
      result = filter_by_price_from(result)
      result = filter_by_price_to(result)
      result
    rescue StandardError => e
      Rails.logger.error("ItemsFilterService error: #{e.message}")
      scope.includes(:iva)
    end

    private

    attr_reader :params, :scope

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

    def stripped_param(key)
      params[key].to_s.strip.presence
    end

    def array_param(key)
      Array(params[key]).map(&:to_s).reject(&:blank?)
    end

    def sanitize(value)
      ActiveRecord::Base.sanitize_sql_like(value)
    end
  end
end
