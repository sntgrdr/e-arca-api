module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { errors: [e.message] }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      rescue_from Pagy::OverflowError do |e|
        render json: { errors: ['Page not found'] }, status: :not_found
      end

      private

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
    end
  end
end
