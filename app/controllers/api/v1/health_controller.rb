module Api
  module V1
    class HealthController < ActionController::API
      def show
        ActiveRecord::Base.connection.execute('SELECT 1')
        render json: { status: 'ok', timestamp: Time.zone.now.iso8601 }
      rescue StandardError => e
        render json: { status: 'error', message: e.message }, status: :service_unavailable
      end
    end
  end
end
