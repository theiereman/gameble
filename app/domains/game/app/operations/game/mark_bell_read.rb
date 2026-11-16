module Game
  # Remembers the bell lines a player has read, so every device they sign in on hides them.
  class MarkBellRead < Operation
    KEYS_PER_CALL = 100
    KEY_FORMAT = /\A[a-z-]+:[A-Za-z0-9:.\-]{1,120}\z/

    def call(player:, keys:, now: Time.current)
      player = step require_player(player)
      keys = step valid_keys(keys)

      transaction do
        step write(player, keys, now)
        step publish(BellLinesRead.new(data: { player_id: player.id, count: keys.size }), stream_name: stream_name(player.id))
        keys
      end
    end

    private

    def valid_keys(keys)
      return Failure(:invalid_keys) unless keys.is_a?(Array) && keys.size.between?(1, KEYS_PER_CALL)
      return Failure(:invalid_keys) unless keys.all? { it.is_a?(String) && KEY_FORMAT.match?(it) }

      Success(keys.uniq)
    end

    def write(player, keys, now)
      BellRead.upsert_all(keys.map { { player_id: player.id, key: it, read_at: now } }, unique_by: %i[player_id key],
        on_duplicate: Arel.sql("read_at = GREATEST(game_bell_reads.read_at, EXCLUDED.read_at), updated_at = EXCLUDED.updated_at"))
      forget_oldest(player)
      Success()
    end

    def forget_oldest(player)
      kept = BellRead.where(player_id: player.id).order(read_at: :desc, id: :desc).limit(BellRead::KEPT_PER_PLAYER).select(:id)
      BellRead.where(player_id: player.id).where.not(id: kept).delete_all
    end
  end
end
