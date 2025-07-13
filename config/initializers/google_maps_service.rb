# frozen_string_literal: true

GoogleMapsService.configure do |config|
  config.key = Rails.application.credentials.google_maps_api_key
  config.retry_timeout = 20
  config.queries_per_second = 10
end
