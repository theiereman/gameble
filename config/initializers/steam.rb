# The Steam Web API key, read by Steam::WebApi. It comes from the
# STEAM_API_KEY environment variable; outside production it falls back to the
# git-ignored config/steam_api.key. Only Steam::WebApi sends it, and it
# redacts it from every error it raises, so it reaches no log, error or page.
Rails.application.configure do
  key_file = Rails.root.join("config/steam_api.key")
  config.x.steam.api_key = ENV["STEAM_API_KEY"].presence ||
    (key_file.read.strip.presence if !Rails.env.production? && key_file.exist?)
end
