module Game
  # Opens a player's next pack (CAP-4, AD-6, AD-7): under the bank lock, the
  # oldest available pack of any kind (by availability time, then id) is
  # marked opened, its cards are credited to the player's holdings in one
  # upsert, ascending card-season, and Game::PackOpened is published.
  # A pack that is not available yet is never opened.
  #
  #   Game::OpenPack.new.call(player:)
  #   # => Success(pack) | Failure(:player_required) | Failure(:no_pack_available)
  class OpenPack < Operation
    def call(player:)
      player = step require_player(player)

      transaction do
        BankLock.acquire(player.id)
        now = Time.current
        pack = step next_pack(player, now)
        pack.update!(opened_at: now)
        step credit(player, pack, now)
        step publish(PackOpened.new(data: { player_id: player.id, pack_id: pack.id }), stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def next_pack(player, now)
      pack = Pack.where(player_id: player.id).available(now).first
      pack ? Success(pack) : Failure(:no_pack_available)
    end

    # One row per card-season, in ascending order so concurrent writers lock
    # holdings in the same order (AD-6); a card drawn twice adds 2.
    def credit(player, pack, now)
      rows = pack.card_season_ids.tally.sort.map do |card_season_id, quantity|
        { player_id: player.id, card_season_id:, quantity:, created_at: now, updated_at: now }
      end
      Holding.upsert_all(rows, unique_by: %i[player_id card_season_id], record_timestamps: false,
        on_duplicate: Arel.sql("quantity = game_holdings.quantity + excluded.quantity, updated_at = excluded.updated_at"))
      Success()
    end
  end
end
