module Game
  class MarkAllocationSeen < Operation
    def call(player:)
      player = step require_player(player)
      season = Catalog::PublishedSeason.call
      return Success(nil) if season.nil?

      transaction do
        step lock_bank(player)
        step ReceiveSeasonAllocation.new.call(player:, season:)
        now = Time.current
        PlayerState.upsert(
          { player_id: player.id, allocation_seen_season: season.number, created_at: now, updated_at: now },
          unique_by: :player_id, record_timestamps: false,
          on_duplicate: Arel.sql("allocation_seen_season = GREATEST(game_player_states.allocation_seen_season, " \
            "excluded.allocation_seen_season), updated_at = excluded.updated_at")
        )
        season.number
      end
    end
  end
end
