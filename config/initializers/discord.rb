# Read by Accounts::DiscordClient: DISCORD_BOT_TOKEN and DISCORD_GUILD_ID, or outside production the git-ignored config/discord_*.key files.
Rails.application.configure do
  read_key = lambda do |name, file|
    path = Rails.root.join(file)
    ENV[name].presence || (path.read.strip.presence if !Rails.env.production? && path.exist?)
  end
  config.x.discord.bot_token = read_key.call("DISCORD_BOT_TOKEN", "config/discord_bot.key")
  config.x.discord.guild_id = read_key.call("DISCORD_GUILD_ID", "config/discord_guild.key")
end
