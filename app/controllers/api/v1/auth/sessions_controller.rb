module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: {
            message: "Sesión iniciada correctamente.",
            user: ActiveModelSerializers::SerializableResource.new(resource, serializer: UserSerializer)
          }, status: :ok
        end

        def respond_to_on_destroy
          if request.cookies[JwtCookieMiddleware::COOKIE_NAME].present?
            response.delete_cookie(
              JwtCookieMiddleware::COOKIE_NAME,
              path: "/",
              secure: Rails.env.production?,
              httponly: true,
              same_site: :lax
            )
            render json: { message: "Sesión cerrada correctamente." }, status: :ok
          else
            render json: { errors: [ "No se encontró sesión activa." ] }, status: :unauthorized
          end
        end
      end
    end
  end
end
