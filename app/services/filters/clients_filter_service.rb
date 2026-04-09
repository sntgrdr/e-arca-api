module Filters
  class ClientsFilterService
    def initialize(params, scope)
      @params = params
      @scope = scope
    end

    def call
      result = scope.includes(:client_group)
      result = filter_by_legal_name(result)
      result = filter_by_legal_number(result)
      result = filter_by_name(result)
      result = filter_by_tax_condition(result)
      result = filter_by_client_group_id(result)
      result
    rescue StandardError => e
      Rails.logger.error("ClientsFilterService error: #{e.message}")
      scope.includes(:client_group)
    end

    private

    attr_reader :params, :scope

    def filter_by_legal_name(result)
      value = stripped_param(:legal_name)
      return result if value.blank?

      result.where("clients.legal_name ILIKE ?", "%#{sanitize(value)}%")
    end

    def filter_by_legal_number(result)
      value = stripped_param(:legal_number)
      return result if value.blank?

      result.where("clients.legal_number ILIKE ?", "%#{sanitize(value)}%")
    end

    def filter_by_name(result)
      value = stripped_param(:name)
      return result if value.blank?

      result.where("clients.name ILIKE ?", "%#{sanitize(value)}%")
    end

    def filter_by_tax_condition(result)
      values = array_param(:tax_condition)
      return result if values.empty?

      result.where(tax_condition: values)
    end

    def filter_by_client_group_id(result)
      values = array_param(:client_group_id)
      return result if values.empty?

      result.where(client_group_id: values)
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
