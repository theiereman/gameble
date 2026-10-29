# Clerk proves who signs in; the app keeps its own session. The secret key
# comes from CLERK_SECRET_KEY; outside production it falls back to the
# git-ignored config/clerk_secret.key. Only Accounts::ClerkClient sends it.
# The publishable key is public: CLERK_PUBLISHABLE_KEY, and outside
# production the development instance's key. The Frontend API host the
# browser talks to is encoded in it.
DEVELOPMENT_CLERK_PUBLISHABLE_KEY = "pk_test_dGhvcm91Z2gtc2hhZC00MzYzLmNsZXJrLmFjY291bnRzLmRldiQ".freeze

Rails.application.configure do
  key_file = Rails.root.join("config/clerk_secret.key")
  config.x.clerk.secret_key = ENV["CLERK_SECRET_KEY"].presence ||
    (key_file.read.strip.presence if !Rails.env.production? && key_file.exist?)
  config.x.clerk.publishable_key = ENV["CLERK_PUBLISHABLE_KEY"].presence ||
    (DEVELOPMENT_CLERK_PUBLISHABLE_KEY unless Rails.env.production?)
  config.x.clerk.frontend_api = config.x.clerk.publishable_key&.then do |key|
    Base64.decode64(key.sub(/\Apk_(?:test|live)_/, "")).delete_suffix("$")
  end
end
