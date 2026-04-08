source 'https://rubygems.org'

gem 'rails', '~> 8.1.1'
gem 'pg', '~> 1.6'
gem 'puma', '>= 5.0'
gem 'bootsnap', require: false
gem 'tzinfo-data', platforms: %i[windows jruby]

# Auth
gem 'devise', '~> 4.9', '>= 4.9.4'
gem 'devise-jwt', '~> 0.12'

# Serialization
gem 'active_model_serializers', '~> 0.10'

# CORS
gem 'rack-cors', '~> 2.0'

# Pagination
gem 'pagy', '~> 9.0'

# Background jobs
gem 'solid_queue'

# AFIP integration
gem 'faraday', '~> 2.14'
gem 'nokogiri'

# PDF generation
gem 'prawn', '~> 2.5'
gem 'prawn-table', '~> 0.2'
gem 'rqrcode', '~> 2.2'
gem 'rubyzip', '~> 2.3'

# i18n
gem 'rails-i18n', '~> 8.0'

group :development, :test do
  gem 'debug'
  gem 'dotenv-rails', '~> 3.2'
  gem 'factory_bot_rails', '~> 6.5'
  gem 'rspec-rails', '~> 8.0.2'
  gem 'brakeman', require: false
  gem 'rubocop-rails-omakase', require: false
end

group :test do
  gem 'shoulda-matchers', '~> 6.4'
end
