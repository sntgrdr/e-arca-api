# frozen_string_literal: true

module Filters
  class CreditNotesFilterService < BaseFilterService
    def call
      result = scope.includes(:client, :sell_point)
      result = filter_by_number(result)
      result = filter_by_date_from(result)
      result = filter_by_date_to(result)
      result = filter_by_period_from(result)
      result = filter_by_period_to(result)
      result = filter_by_client_legal_name(result)
      result = filter_by_total_from(result)
      result = filter_by_total_to(result)
      result = filter_by_sell_point_id(result)
      result = filter_by_client_id(result)
      result
    rescue StandardError => e
      Rails.logger.error("CreditNotesFilterService error: #{e.message}")
      scope.includes(:client, :sell_point)
    end

    private

    def filter_by_number(result)
      value = stripped_param(:number)
      return result if value.blank?

      result.where("invoices.number ILIKE ?", "%#{sanitize(value)}%")
    end

    def filter_by_date_from(result)
      value = stripped_param(:date_from)
      return result if value.blank?

      result.where("invoices.date >= ?", value)
    end

    def filter_by_date_to(result)
      value = stripped_param(:date_to)
      return result if value.blank?

      result.where("invoices.date <= ?", value)
    end

    def filter_by_period_from(result)
      value = stripped_param(:period_from)
      return result if value.blank?

      result.where("invoices.period >= ?", value)
    end

    def filter_by_period_to(result)
      value = stripped_param(:period_to)
      return result if value.blank?

      result.where("invoices.period <= ?", value)
    end

    def filter_by_client_legal_name(result)
      value = stripped_param(:client_legal_name)
      return result if value.blank?

      result.left_joins(:client).where("clients.legal_name ILIKE ?", "%#{sanitize(value)}%").references(:clients)
    end

    def filter_by_total_from(result)
      value = stripped_param(:total_from)
      return result if value.blank?

      result.where("invoices.total_price >= ?", value.to_f)
    end

    def filter_by_total_to(result)
      value = stripped_param(:total_to)
      return result if value.blank?

      result.where("invoices.total_price <= ?", value.to_f)
    end

    def filter_by_sell_point_id(result)
      value = stripped_param(:sell_point_id)
      return result if value.blank?

      result.where(sell_point_id: value)
    end

    def filter_by_client_id(result)
      value = stripped_param(:client_id)
      return result if value.blank?

      result.where(client_id: value)
    end
  end
end
