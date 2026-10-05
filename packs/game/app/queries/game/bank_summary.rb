module Game
  # What a player's chest shows (R9): their reserve, the packs they can open
  # now, of every kind (Game::Reserve), whether it is full, and when the next
  # pack of the bank comes (R4): the earliest future availability time among
  # the unopened regular packs, nil when every one is available or the
  # player has no bank. Bonus and reward packs never move it.
  # `bonus_collectable`: a season is published and the player has no daily
  # bonus claim for the UTC day of `now` (CAP-16), the same two checks as
  # Game::CollectDailyBonus, without loading the draw pool. `reserve_full`:
  # the reserve holds Game::Reserve::FULL, so a collection would be refused
  # (AD-7); the same query as the operation's.
  #
  #   Game::BankSummary.call(player)
  #   # => { available: n, reserve_full: true | false, next_available_at: Time | nil,
  #   #      bonus_collectable: true | false }
  module BankSummary
    def self.call(player, now: Time.current)
      available = Reserve.count(player.id, now:)
      {
        available:,
        reserve_full: Reserve.full?(available),
        next_available_at: Pack.bank(player.id).where.not(available_at: ..now).minimum(:available_at),
        bonus_collectable: Catalog::PublishedSeason.call.present? &&
          !DailyBonusClaim.exists?(player_id: player.id, day: DailyBonusClaim.day_of(now))
      }
    end
  end
end
