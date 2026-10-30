require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gameble
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # app/domains holds packages, not an autoload root: each domain's own app/* directories are the roots.
    config.paths["app"].instance_variable_get(:@exclude) << "domains"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Every page exists in French and English; English is the fallback.
    config.i18n.available_locales = %i[en fr]
    config.i18n.default_locale = :en

    # Read at request time: ErrorPage is reloadable app code.
    config.exceptions_app = ->(env) { ErrorPage.call(env) }

    # Active Storage's own URLs carry signed blob ids, database ids: the stored files are served by token instead.
    config.active_storage.draw_routes = false
  end
end
