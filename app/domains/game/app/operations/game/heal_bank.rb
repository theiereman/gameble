module Game
  # Brings a player's packs to the published season: under the bank lock, a
  # bank left short of ten — mainly by openings while no season was
  # published, so nothing replaced them — gets its missing regular packs,
  # all available now, at once (Game::TopUpBank.heal), and every unopened
  # pack of any kind still of an earlier season is drawn again in the
  # published one, in place (Game::PackRedraw): it keeps its id, token, kind
  # and availability time. One Game::BankToppedUp is published when a pack
  # was inserted or redrawn. Idempotent: a full bank of the published season,
  # a player who never had a pack (Game::FillBank's job) or a game with no
  # published season gets nothing and publishes nothing; an opened pack is
  # never redrawn.
  #
  # Run only when a season is published, with no retry and no fill on use
  # (author, 2026-10-07): by Game::HealBanksJob for every player that had a
  # pack and whose bank is short of ten or holds a pack of an earlier
  # season, and in development by `bin/rails game:top_up_banks`, which runs
  # that job.
  #
  #   Game::HealBank.new.call(player:)
  #   # => Success(packs inserted) | Failure(:player_required)
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
