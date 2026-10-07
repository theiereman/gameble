module Game
  # Heals the bank of a player left short of ten — mainly one who opened
  # their last pack while no season was published, or a bank from a build
  # before openings were replaced (CAP-4, AD-7): under the bank lock,
  # the missing regular packs are drawn and all made available now, at once
  # (Game::TopUpBank, `immediate: true`; the author's decision of 2026-10-07:
  # a bank is healed only when a season is published, with no retry and no
  # fill on use), and Game::BankToppedUp is published. Idempotent: a
  # full bank, a player who never had a pack (Game::FillBank's job) or a game
  # with no published season gets nothing and publishes nothing.
  #
  # Run by Game::HealBanksJob, when a season is published and by
  # `bin/rails game:top_up_banks`, for every player that had a pack and whose
  # bank is short of ten.
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
        BankLock.acquire(player.id)
        next 0 unless Pack.exists?(player_id: player.id)

        inserted = TopUpBank.call(player_id: player.id, now: Time.current, random: @random, immediate: true)
        next 0 if inserted.zero?

        step publish(BankToppedUp.new(data: { player_id: player.id, packs: inserted }), stream_name: stream_name(player.id))
        inserted
      end
    end
  end
end
