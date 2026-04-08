require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module EArcaApi
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true

    config.i18n.available_locales = [:es]
    config.i18n.default_locale = :es

    config.active_job.queue_adapter = :solid_queue

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
  end
end
