module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend
      include Pundit::Authorization

      before_action :authenticate_user!
      before_action :set_paper_trail_whodunnit
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      # NOTE: rescue_from is matched in reverse declaration order (last declared = first checked).
      # StandardError must be declared FIRST so specific handlers take precedence.
      rescue_from StandardError do |e|
        Rails.logger.error("[500] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
        render json: { error: { code: "internal_error", message: "An unexpected error occurred" } }, status: :internal_server_error
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        Rails.logger.warn("[404] #{e.class}: #{e.message}")
        render json: { error: { code: "not_found", message: "Resource not found" } }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        Rails.logger.warn("[422] #{e.class}: #{e.message}")
        render json: { errors: e.record.errors.messages }, status: :unprocessable_entity
      end

      rescue_from Pagy::OverflowError do |_e|
        render json: { error: { code: "not_found", message: "Page not found" } }, status: :not_found
      end

      rescue_from Pundit::NotAuthorizedError do |_e|
        render json: { error: { code: "forbidden", message: "You are not authorized to perform this action" } }, status: :forbidden
      end

      private

      def user_for_paper_trail
        current_user&.id&.to_s
      end

      def render_errors(messages, status = :unprocessable_entity)
        render json: { errors: Array(messages) }, status: status
      end

      def paginate(collection)
        pagy, records = pagy(collection)
        {
          data: records,
          pagination: {
            count: pagy.count,
            page: pagy.page,
            items: pagy.limit,
            pages: pagy.last
          }
        }
      end

      def render_paginated(result, serializer:)
        render json: {
          data: ActiveModelSerializers::SerializableResource.new(
            result[:data],
            each_serializer: serializer
          ),
          meta: result[:pagination]
        }
      end

      def arca_service_module
        Rails.env.production? ? Invoices::Production : Invoices::Development
      end
    end
  end
end
