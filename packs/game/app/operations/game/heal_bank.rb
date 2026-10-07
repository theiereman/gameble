module Game
  # Heals the bank of a player left short of ten — mainly one who opened
  # packs while no season was published, so they were not replaced
  # (CAP-4, AD-7): under the bank lock, the missing regular packs are drawn
  # and all made available now, at once (Game::TopUpBank.heal), and
  # Game::BankToppedUp is published. Idempotent: a full bank, a player who
  # never had a pack (Game::FillBank's job) or a game with no published
  # season gets nothing and publishes nothing.
  #
  # A bank is healed only when a season is published, with no retry and no
  # fill on use (author, 2026-10-07): run by Game::HealBanksJob for every
  # player that had a pack and whose bank is short of ten, and in
  # development by `bin/rails game:top_up_banks`, which runs that job.
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
        next 0 if inserted.zero?

        step publish(BankToppedUp.new(data: { player_id: player.id, packs: inserted }), stream_name: stream_name(player.id))
        inserted
      end
    end
  end
end
