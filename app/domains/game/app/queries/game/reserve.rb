module Game
  # A player's reserve (AD-7): every unopened pack, of any kind (regular,
  # daily bonus, weekly reward), already available at `now`. It is the count
  # the chest shows, and the daily bonus is refused while it holds FULL:
  # Game::BankSummary and Game::CollectDailyBonus both read it here, the one
  # query. Not the bank (Pack::BANK_SIZE), which counts regular packs only,
  # scheduled ones included.
  #
  #   count = Game::Reserve.count(player.id, now:) # => 0..
  #   Game::Reserve.full?(count)                   # => true from FULL up
  module Reserve
    # Available packs at which the daily bonus is refused (reserve_full).
    FULL = 10

    def self.count(player_id, now: Time.current)
      Pack.where(player_id:).available(now).count
    end

    def self.full?(count)
      count >= FULL
    end
  end
end
