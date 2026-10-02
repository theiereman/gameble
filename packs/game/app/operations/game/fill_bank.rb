module Game
  # Fills the bank of a player who never had a pack (CAP-4, AD-7): ten
  # regular packs, available now, of five cards each drawn from the published
  # season, inserted in one statement under the bank lock, and
  # Game::BankFilled. Idempotent: a player who ever had a pack, or a game
  # with no published season, gets nothing and publishes nothing.
  #
  # Called on sign-up (Game::Handlers::PlayerRegistered) and, for the players
  # left without a bank, when a season is published (Game::FillEmptyBanksJob).
  #
  #   Game::FillBank.new.call(player:)
  #   # => Success(packs inserted, 0 or BANK_SIZE) | Failure(:player_required)
  class FillBank < Operation
    # Packs in a full bank.
    BANK_SIZE = 10

    def call(player:)
      player = step require_player(player)

      transaction do
        BankLock.acquire(player.id)
        next 0 if Pack.exists?(player_id: player.id)

        pool = DrawPool.current
        next 0 if pool.nil?

        step insert_packs(player, pool)
        step publish(BankFilled.new(data: { player_id: player.id }), stream_name: stream_name(player.id))
        BANK_SIZE
      end
    end

    private

    def insert_packs(player, pool)
      now = Time.current
      Pack.insert_all!(Array.new(BANK_SIZE) do
        { player_id: player.id, token: Pack.generate_unique_secure_token, kind: "regular", season_id: pool.season_id,
          card_season_ids: Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, pool:), available_at: now }
      end)
      Success()
    end
  end
end
