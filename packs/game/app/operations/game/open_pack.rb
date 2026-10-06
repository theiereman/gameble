module Game
  # Opens a player's next pack (CAP-4, AD-6, AD-7): under the bank lock, the
  # oldest available pack of any kind (by availability time, then id) is
  # marked opened, with the card back the player has on (Game::CardBacks),
  # its cards are credited to the player's holdings in one upsert, ascending
  # card-season, each marked as gained at the opening (AD-26), and
  # Game::PackOpened is published.
  # A pack that is not available yet is never opened. Opening a regular pack
  # tops the bank back up to ten in the same transaction (Game::TopUpBank);
  # a bonus or reward pack tops up nothing.
  #
  # The booster's JSON exchange (AD-23) passes the request's Idempotency-Key,
  # a UUID, stored on the opened pack. Under the bank lock (AD-10), before the
  # availability check, a pack of the player's that already carries the key
  # is returned as it is: a replay opens nothing, credits nothing, tops up
  # nothing and publishes nothing, even with no pack available. A request
  # sharing the key waits on the lock for the first to commit, then replays
  # it. A malformed key is refused before any write. Without a key (the HTML
  # form) the pack opens as before and keeps no key.
  #
  #   Game::OpenPack.new.call(player:, idempotency_key: nil)
  #   # => Success(pack) | Failure(:player_required) | Failure(:invalid_idempotency_key)
  #   #    | Failure(:no_pack_available)
  class OpenPack < Operation
    # A UUID in its canonical form, any case.
    IDEMPOTENCY_KEY = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    # Whether the key is a well-formed one that a pack of the player's
    # already carries: the request would replay it. One indexed lookup,
    # outside the lock, for the web layer's rate limit (a replay is not
    # counted); the lookup that decides is the one under the lock in `call`.
    def self.replay?(player, idempotency_key)
      player.present? && idempotency_key.is_a?(String) && idempotency_key.match?(IDEMPOTENCY_KEY) &&
        Pack.exists?(player_id: player.id, idempotency_key:)
    end

    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:, idempotency_key: nil)
      player = step require_player(player)
      step check_key(idempotency_key)

      transaction do
        BankLock.acquire(player.id)
        replayed = idempotency_key && Pack.find_by(player_id: player.id, idempotency_key:)
        next replayed if replayed

        now = Time.current
        pack = step next_pack(player, now)
        pack.update!(opened_at: now, idempotency_key:, card_back: CardBacks.active_key(player))
        step credit(player, pack, now)
        TopUpBank.call(player_id: player.id, now:, random: @random) if pack.regular?
        step publish(PackOpened.new(data: { player_id: player.id, pack_id: pack.id }), stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def check_key(key)
      key.nil? || (key.is_a?(String) && key.match?(IDEMPOTENCY_KEY)) ? Success() : Failure(:invalid_idempotency_key)
    end

    def next_pack(player, now)
      pack = Pack.where(player_id: player.id).available(now).first
      pack ? Success(pack) : Failure(:no_pack_available)
    end

    # One row per card-season, in ascending order so concurrent writers lock
    # holdings in the same order (AD-6); a card drawn twice adds 2. Every
    # credited holding gained copies now (AD-26: its NOUVEAU tag), whether
    # inserted or raised.
    def credit(player, pack, now)
      rows = pack.card_season_ids.tally.sort.map do |card_season_id, quantity|
        { player_id: player.id, card_season_id:, quantity:, last_gained_at: now, created_at: now, updated_at: now }
      end
      Holding.upsert_all(rows, unique_by: %i[player_id card_season_id], record_timestamps: false,
        on_duplicate: Arel.sql("quantity = game_holdings.quantity + excluded.quantity, " \
          "last_gained_at = excluded.last_gained_at, updated_at = excluded.updated_at"))
      Success()
    end
  end
end
