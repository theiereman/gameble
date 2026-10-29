source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.7"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.2"
# image_processing 2 no longer pulls its image library in; the card filter uses libvips
gem "ruby-vips", "~> 2.2", require: false

# Bundle and serve frontend assets with Vite [https://vite-ruby.netlify.app/]
gem "vite_rails", "~> 3.11.1"

# Hotwire for server-rendered pages (AD-16) [https://turbo.hotwired.dev] [https://stimulus.hotwired.dev]
gem "turbo-rails", "~> 2.0.23"
gem "stimulus-rails", "~> 1.3.4"

# Load domain code from app/domains/ [https://github.com/rubyatscale/packs-rails]
gem "packs-rails", "~> 0.1.0"

# Refuse migrations that would block the database [https://github.com/ankane/strong_migrations]
gem "strong_migrations", "~> 2.8.0"

# Write every state change as an operation returning Success or Failure (AD-3) [https://github.com/dry-rb/dry-operation]
gem "dry-operation", "~> 1.1.0"

# Publish domain events inside the operation's transaction (AD-10) [https://railseventstore.org]
gem "rails_event_store", "~> 3.2.0"

# Build the shared view parts as tested components (AD-16) [https://viewcomponent.org]
gem "view_component", "~> 4.16.0"

# Pick the first-visit locale from the browser's Accept-Language (AD-18) [https://github.com/iain/http_accept_language]
gem "http_accept_language", "~> 2.1.1"

# Page long lists, such as the library's shelves (Consistency Conventions: Pagination) [https://github.com/ddnexus/pagy]
gem "pagy", "~> 43.8.1"

# Sign in with Steam over OpenID 2.0, POST-only and CSRF-protected (AD-14) [https://github.com/omniauth/omniauth]
gem "omniauth", "~> 2.1.4"
gem "omniauth-openid", "~> 2.0.2"
gem "omniauth-rails_csrf_protection", "~> 2.0.1"
# ruby-openid needs REXML, which Ruby 4 no longer bundles
gem "rexml", "~> 3.4.4"
# ruby-openid calls CGI.parse when it checks return_to; Ruby 4 keeps only cgi/escape
gem "cgi", "~> 0.5.2"

# A policy on every controller action, deny by default (AD-14) [https://github.com/varvet/pundit]
gem "pundit", "~> 2.5.2"

# Address cards by a stable slug, never by their id (AD-15) [https://github.com/norman/friendly_id]
gem "friendly_id", "~> 5.7.0"

# Report production errors, without personal data (AD-21) [https://github.com/getsentry/sentry-ruby]
gem "sentry-rails", "~> 7.1.0"

# Watch and retry jobs from the back-office, administrators only [https://github.com/rails/mission_control-jobs]
gem "mission_control-jobs", "~> 1.3.1"

# Call the Steam Web API, retrying 429 and 5xx with backoff (AD-19) [https://github.com/lostisland/faraday]
gem "faraday", "~> 2.15.0"
gem "faraday-retry", "~> 2.4.0"

# Read the initiative's epics from its TOML ticket file to create the roadmap milestones [https://github.com/fbernier/tomlrb]
gem "tomlrb", "~> 3.0.0"

# Throttle the sign-in endpoints per client IP, before the OmniAuth middleware [https://github.com/rack/rack-attack]
gem "rack-attack", "~> 6.8.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Check the pack dependency direction [https://github.com/Shopify/packwerk]
  gem "packwerk", "~> 3.3.1", require: false

  # Find missing translations [https://github.com/glebm/i18n-tasks]
  gem "i18n-tasks", "~> 1.1.2", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

gem "jwt", "~> 3.3"
