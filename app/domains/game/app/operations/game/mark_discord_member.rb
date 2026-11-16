module Game
  class MarkDiscordMember < Operation
    def call(player:, member:, now: Time.current)
      player = step require_player(player)

      transaction do
        PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
        changes = member ? { discord_member_at: now, discord_checked_at: now } : { discord_checked_at: now }
        first = PlayerState.where(player_id: player.id, discord_member_at: nil).update_all(changes.merge(updated_at: now)).positive?
        found = member && first
        step publish(DiscordMemberFound.new(data: { player_id: player.id }), stream_name: stream_name(player.id)) if found
        found
      end
    end
  end
end
