source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
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
gem "image_processing", "~> 1.2"

# Bundle and serve frontend assets with Vite [https://vite-ruby.netlify.app/]
gem "vite_rails", "~> 3.11.1"

# Load domain code from packs/ [https://github.com/rubyatscale/packs-rails]
gem "packs-rails", "~> 0.1.0"

# Refuse migrations that would block the database [https://github.com/ankane/strong_migrations]
gem "strong_migrations", "~> 2.8.0"

# Write every state change as an operation returning Success or Failure (AD-3) [https://github.com/dry-rb/dry-operation]
gem "dry-operation", "~> 1.1.0"

# Publish domain events inside the operation's transaction (AD-10) [https://railseventstore.org]
gem "rails_event_store", "~> 3.2.0"

# Build the shared view parts as tested components (AD-16) [https://viewcomponent.org]
gem "view_component", "~> 4.15.0"

# Pick the first-visit locale from the browser's Accept-Language (AD-18) [https://github.com/iain/http_accept_language]
gem "http_accept_language", "~> 2.1.1"

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
