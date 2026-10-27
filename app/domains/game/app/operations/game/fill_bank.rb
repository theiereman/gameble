module Game
  # Fills the bank of a player who never had a pack (CAP-4, AD-7): ten
  # regular packs, available now, of five cards each drawn from the published
  # season with the first-session guarantee (FirstSessionGuarantee), inserted
  # in one statement under the bank lock, and
  # Game::BankFilled. Idempotent: a player who ever had a pack, or a game
  # with no published season, gets nothing and publishes nothing.
  #
  # Called on sign-up (Game::Handlers::PlayerRegistered), for the players
  # left without a bank when a season is published (Game::HealBanksJob), and
  # before a daily bonus for a player without a bank (Game::CollectDailyBonus).
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

    # `now`: the packs' availability time; a caller holding its own `now`
    # (Game::CollectDailyBonus) passes it so its later packs open after these.
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
      # Rows keep their order, and insert_all! numbers them in that order:
      # the opening order (available_at, id) is the order of `draws`.
      Pack.insert_all!(FirstSessionGuarantee.apply(draws, pool:, random: @random).map do |cards|
        Pack.row(player_id: player.id, kind: :regular, season_id: pool.season_id, card_season_ids: cards, available_at: now)
      end)
      Success()
    end
  end
end
