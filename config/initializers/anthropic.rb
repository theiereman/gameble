# The Claude API key the back office condenses and translates release notes and the roadmap with. It comes from
# ANTHROPIC_API_KEY; outside production it falls back to the git-ignored config/anthropic_api.key.
# Only Accounts::ClaudeWriter sends it.
Rails.application.configure do
  key_file = Rails.root.join("config/anthropic_api.key")
  config.x.anthropic.api_key = ENV["ANTHROPIC_API_KEY"].presence ||
    (key_file.read.strip.presence if !Rails.env.production? && key_file.exist?)
end
