module Game
  # Collects a player's daily bonus (CAP-16, AD-7, AD-9): once per UTC day, a
  # bonus pack of Pack::BONUS_SIZE cards drawn with DrawOdds::BONUS, available
  # now, outside the bank's cap of ten. It opens like any pack, in arrival
  # order: after the packs already available. Under the bank lock, with `now`
  # taken once:
  #
  # 1. a claim for the UTC day of `now` exists: Failure(:already_collected);
  # 2. no published season: Failure(:no_season), and no claim, so the player
  #    can collect later that day;
  # 3. a player without a bank gets their ten packs first (Game::FillBank,
  #    with the first-session guarantee; the lock is re-entrant);
  # 4. the bonus pack is inserted, then the claim (Game::DailyBonusClaim),
  #    and Game::DailyBonusCollected is published.
  #
  # The lock serialises a player's collections; the unique index on
  # (player_id, day) is the database's guarantee behind it.
  #
  #   Game::CollectDailyBonus.new.call(player:)
  #   # => Success(pack) | Failure(:player_required) | Failure(:already_collected) | Failure(:no_season)
  class CollectDailyBonus < Operation
    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:)
      player = step require_player(player)

      transaction do
        BankLock.acquire(player.id)
        now = Time.current
        day = DailyBonusClaim.day_of(now)
        step unclaimed(player, day)
        pool = step published_pool
        step FillBank.new(random: @random).call(player:, now:)
        pack = Pack.create!(player_id: player.id, kind: :bonus, season_id: pool.season_id, available_at: now,
          card_season_ids: Draw.pack(odds: DrawOdds::BONUS, size: Pack::BONUS_SIZE, random: @random, pool:))
        DailyBonusClaim.create!(player_id: player.id, day:, pack_id: pack.id)
        step publish(DailyBonusCollected.new(data: { player_id: player.id, pack_id: pack.id }), stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def unclaimed(player, day)
      DailyBonusClaim.exists?(player_id: player.id, day:) ? Failure(:already_collected) : Success()
    end

    def published_pool
      pool = DrawPool.current
      pool ? Success(pool) : Failure(:no_season)
    end
  end
end
