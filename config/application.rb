require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tripyo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Set available languages
    config.i18n.available_locales = [:en, :es, :pt]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [I18n.default_locale]

    # Disable host authorization in test environment
    if Rails.env.test?
      config.hosts.clear
      config.hosts << "www.example.com"
      config.hosts << "example.com"
      config.hosts << "test.host"
    end
  end
end
