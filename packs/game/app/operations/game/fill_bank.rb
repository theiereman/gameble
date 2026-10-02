module Game
  # Fills the bank of a player who never had a pack (CAP-4, AD-7): ten
  # regular packs, available now, of five cards each drawn from the published
  # season with the first-session guarantee (FirstSessionGuarantee), inserted
  # in one statement under the bank lock, and
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
    BANK_SIZE = Pack::BANK_SIZE

    def initialize(random: SecureRandom)
      super()
      @random = random
    end

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
      draws = Array.new(BANK_SIZE) { Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, random: @random, pool:) }
      # Rows keep their order, and insert_all! numbers them in that order:
      # the opening order (available_at, id) is the order of `draws`.
      Pack.insert_all!(FirstSessionGuarantee.apply(draws, pool:, random: @random).map do |cards|
        { player_id: player.id, token: Pack.generate_unique_secure_token, kind: "regular", season_id: pool.season_id,
          card_season_ids: cards, available_at: now }
      end)
      Success()
    end
  end
end
