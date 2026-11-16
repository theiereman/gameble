module Game
  module DiscordMembershipsDue
    Entry = Data.define(:player_id, :discord_user_id)

    SQL = <<~SQL.squish.freeze
      SELECT identities.player_id, identities.uid
        FROM accounts_identities identities
        JOIN accounts_players players ON players.id = identities.player_id
         AND players.banned_at IS NULL AND players.deleted_at IS NULL
        LEFT JOIN game_player_states states ON states.player_id = identities.player_id
       WHERE identities.provider = 'discord' AND states.discord_member_at IS NULL
       ORDER BY states.discord_checked_at ASC NULLS FIRST, identities.player_id
       LIMIT :limit
    SQL

    def self.call(limit:)
      rows = PlayerState.connection.select_rows(PlayerState.sanitize_sql_array([ SQL, { limit: } ]))
      rows.map { |player_id, uid| Entry.new(player_id:, discord_user_id: uid) }
    end
  end
end
