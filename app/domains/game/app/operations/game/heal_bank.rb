module Game
  class HealBank < Operation
    def initialize(random: SecureRandom)
      super()
      @random = random
    end

    def call(player:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        next 0 unless Pack.exists?(player_id: player.id)

        inserted = TopUpBank.heal(player_id: player.id, now: Time.current, random: @random)
        redrawn = redraw_earlier_seasons(player)
        next 0 if inserted.zero? && redrawn.zero?

        step publish(BankToppedUp.new(data: { player_id: player.id, packs: inserted, redrawn: }), stream_name: stream_name(player.id))
        inserted
      end
    end

    private

    def redraw_earlier_seasons(player)
      pool = DrawPool.current
      return 0 if pool.nil?

      stale = Pack.unopened.where(player_id: player.id).where.not(season_id: pool.season_id).order(:id).to_a
      PackRedraw.call(stale, pool:, random: @random).each { |pack, attributes| pack.update!(attributes) }.size
    end
  end
end
