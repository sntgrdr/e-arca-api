module Filters
  class ClientsFilterService < BaseFilterService
    def call
      result = scope.includes(:client_group)
      result = filter_by_q(result)
      result = filter_by_legal_number(result)
      result = filter_by_tax_condition(result)
      result = filter_by_client_group_id(result)
      result
    rescue StandardError => e
      Rails.logger.error("ClientsFilterService error: #{e.message}")
      scope.includes(:client_group)
    end

    private

    # Searches both legal_name and commercial name (OR logic)
    def filter_by_q(result)
      value = stripped_param(:q)
      return result if value.blank?

      sanitized = sanitize(value)
      result.where(
        "clients.legal_name ILIKE ? OR clients.name ILIKE ?",
        "%#{sanitized}%", "%#{sanitized}%"
      )
    end

    # Strips dashes from the search term before matching — stored values are already digit-only
    def filter_by_legal_number(result)
      value = stripped_param(:legal_number)&.gsub("-", "")
      return result if value.blank?

      result.where("clients.legal_number ILIKE ?", "%#{sanitize(value)}%")
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

  end
end
