module Game
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
