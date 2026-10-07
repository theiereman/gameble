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
  # 3. the reserve (Game::Reserve, the query the page reads) holds
  #    Game::Reserve::FULL packs: Failure(:reserve_full), and no claim. It is
  #    read before the fill, as the page shows it: a player without a bank
  #    has a reserve of 0;
  # 4. a player without a bank gets their ten packs first (Game::FillBank,
  #    with the first-session guarantee; the lock is re-entrant);
  # 5. the bonus pack is inserted, then the claim (Game::DailyBonusClaim),
  #    and Game::DailyBonusCollected is published.
  #
  # The lock serialises a player's collections; the unique index on
  # (player_id, day) is the database's guarantee behind it.
  #
  #   Game::CollectDailyBonus.new.call(player:)
  #   # => Success(pack) | Failure(:player_required) | Failure(:already_collected) | Failure(:no_season)
  #   #    | Failure(:reserve_full)
  class CollectDailyBonus < Operation
    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        now = Time.current
        day = DailyBonusClaim.day_of(now)
        step unclaimed(player, day)
        pool = step published_pool
        step room_in_reserve(player, now)
        step FillBank.new(random: @random).call(player:, now:)
        pack = Pack.create!(Pack.row(player_id: player.id, kind: :bonus, season_id: pool.season_id, available_at: now,
          card_season_ids: Draw.pack(odds: DrawOdds::BONUS, size: Pack::BONUS_SIZE, random: @random, pool:)))
        DailyBonusClaim.create!(player_id: player.id, day:, pack_id: pack.id)
        step publish(DailyBonusCollected.new(data: { player_id: player.id, pack_id: pack.id }), stream_name: stream_name(player.id))
        pack
      end
    end

    private

    def unclaimed(player, day)
      DailyBonusClaim.exists?(player_id: player.id, day:) ? Failure(:already_collected) : Success()
    end

    def room_in_reserve(player, now)
      Reserve.full?(Reserve.count(player.id, now:)) ? Failure(:reserve_full) : Success()
    end

    def published_pool
      pool = DrawPool.current
      pool ? Success(pool) : Failure(:no_season)
    end
  end
end
