module Game
  class MarkCollectionSeen < Operation
    def call(player:, up_to:)
      player = step require_player(player)
      up_to = step check_time(up_to)

      transaction do
        step lock_bank(player)
        now = Time.current
        result = PlayerState.upsert(
          { player_id: player.id, collection_seen_up_to: [ up_to, now ].min, created_at: now, updated_at: now, **PlayerState.markers_at_published_season },
          unique_by: :player_id, record_timestamps: false, returning: :collection_seen_up_to,
          on_duplicate: Arel.sql("collection_seen_up_to = GREATEST(game_player_states.collection_seen_up_to, " \
            "excluded.collection_seen_up_to), updated_at = excluded.updated_at")
        )
        PlayerState.type_for_attribute(:collection_seen_up_to).deserialize(result.rows.sole.sole)
      end
    end

    private

    def check_time(value)
      value.is_a?(Time) ? Success(value) : Failure(:invalid_time)
    end
  end
end
