module Game
  class FillBank < Operation
    BANK_SIZE = Pack::BANK_SIZE

    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:, now: Time.current)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        next 0 if Pack.exists?(player_id: player.id)

        pool = DrawPool.current
        next 0 if pool.nil?

        step insert_packs(player, pool, now)
        step publish(BankFilled.new(data: { player_id: player.id }), stream_name: stream_name(player.id))
        BANK_SIZE
      end
    end

    private

    def insert_packs(player, pool, now)
      draws = Array.new(BANK_SIZE) { Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, random: @random, pool:) }
      Pack.insert_all!(FirstSessionGuarantee.apply(draws, pool:, random: @random).map do |cards|
        Pack.row(player_id: player.id, kind: :regular, season_id: pool.season_id, card_season_ids: cards, available_at: now)
      end)
      Success()
    end
  end
end
