module Game
  class CheckDiscordMembershipsJob < ActiveJob::Base
    queue_as :default

    BATCH_SIZE = 50

    def perform(client: Accounts::DiscordClient.new, now: Time.current)
      return unless client.configured?

      DiscordMembershipsDue.call(limit: BATCH_SIZE).each do |entry|
        player = Accounts::PlayerById.call(entry.player_id)
        MarkDiscordMember.new.call(player:, member: member?(client, entry), now:)
      end
    rescue Accounts::DiscordClient::RateLimited
      nil
    end

    private

    def member?(client, entry)
      client.member?(entry.discord_user_id)
    rescue Accounts::DiscordClient::RateLimited
      raise
    rescue Accounts::DiscordClient::Error => error
      Rails.error.report(error, handled: true)
      false
    end
  end
end
