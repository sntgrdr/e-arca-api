# frozen_string_literal: true

module Filters
  class BaseFilterService
    def initialize(params, scope)
      @params = params
      @scope = scope
    end

    private

    attr_reader :params, :scope

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
