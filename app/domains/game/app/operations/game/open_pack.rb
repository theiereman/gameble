module Game
  class OpenPack < Operation
    IDEMPOTENCY_KEY = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

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
        step lock_bank(player)
        season = Catalog::PublishedSeason.call
        replayed = idempotency_key && Pack.find_by(player_id: player.id, idempotency_key:)
        next replayed if replayed

        now = Time.current
        pack = step next_pack(player, now)
        pool = DrawPool.of(season)
        pack.update!(opened_at: now, idempotency_key:, card_back: CardBacks.active_key(player), **drawn_in_published_season(pack, pool))
        step credit(player, pack, now)
        discovered = FirstDiscovery.record(pack, now)
        reached = tiers_reached(player, pack, season, now)
        TopUpBank.call(player_id: player.id, now:, pool:, random: @random) if pack.regular?
        step publish(PackOpened.new(data: { player_id: player.id, pack_id: pack.id }), stream_name: stream_name(player.id))
        step publish_discoveries(player, pack, discovered)
        step publish_tiers(player.id, reached)
        pack
      end
    end

    private

    def publish_discoveries(player, pack, card_season_ids)
      card_season_ids.each do |card_season_id|
        publish(CardDiscovered.new(data: { player_id: player.id, card_season_id:, pack_id: pack.id }), stream_name: stream_name(player.id))
      end
      Success()
    end

    def drawn_in_published_season(pack, pool)
      return {} if pool.nil?

      PackRedraw.call([ pack ], pool:, random: @random).fetch(pack, {})
    end

    def tiers_reached(player, pack, season, now)
      return [] if season.nil?

      SetTier.record(player_id: player.id, card_season_ids: pack.card_season_ids, season_id: season.id, reached_by: "pack", pack_id: pack.id, now:)
    end

    def check_key(key)
      key.nil? || (key.is_a?(String) && key.match?(IDEMPOTENCY_KEY)) ? Success() : Failure(:invalid_idempotency_key)
    end

    def next_pack(player, now)
      pack = Pack.where(player_id: player.id).available(now).first
      pack ? Success(pack) : Failure(:no_pack_available)
    end

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
