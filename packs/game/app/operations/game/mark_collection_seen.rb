module Game
  # Moves a player's collection watermark forward (AD-26): the cards gained
  # up to `up_to` are no longer new (Game::CollectionSlots). The page that
  # showed new cards posts the latest gain it showed; the watermark keeps
  # the greater of its value and that one, so an older or repeated post
  # changes nothing. A time in the future is stored as now, so a forged one
  # cannot hide cards gained later. Full microsecond precision.
  #
  # Under the bank lock, so a deletion is seen and no row recreated for it:
  # one upsert of the player's Game::PlayerState row (created when missing),
  # ON CONFLICT keeping GREATEST of both values. Housekeeping: it publishes
  # no event.
  #
  #   Game::MarkCollectionSeen.new.call(player:, up_to: Time)
  #   # => Success(watermark) | Failure(:player_required) | Failure(:invalid_time)
  class MarkCollectionSeen < Operation
    def call(player:, up_to:)
      player = step require_player(player)
      up_to = step check_time(up_to)

      transaction do
        step lock_bank(player)
        now = Time.current
        result = PlayerState.upsert(
          { player_id: player.id, collection_seen_up_to: [ up_to, now ].min, created_at: now, updated_at: now },
          unique_by: :player_id, record_timestamps: false, returning: :collection_seen_up_to,
          on_duplicate: Arel.sql("collection_seen_up_to = GREATEST(game_player_states.collection_seen_up_to, " \
            "excluded.collection_seen_up_to), updated_at = excluded.updated_at")
        )
        PlayerState.type_for_attribute(:collection_seen_up_to).deserialize(result.rows.sole.sole)
      end
    end

    private

    # A Time or an ActiveSupport::TimeWithZone (which answers is_a?(Time)).
    def check_time(value)
      value.is_a?(Time) ? Success(value) : Failure(:invalid_time)
    end
  end
end
