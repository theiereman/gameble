module Game
  # What a player's chest shows (R9): the packs they can open now, of every
  # kind, and when the next pack of the bank comes (R4): the earliest future
  # availability time among the unopened regular packs, nil when every one
  # is available or the player has no bank. Bonus and reward packs never
  # move it. `bonus_collectable`: a season is published and the player has
  # no daily bonus claim for the UTC day of `now` (CAP-16), the same two
  # checks as Game::CollectDailyBonus, without loading the draw pool.
  #
  #   Game::BankSummary.call(player)
  #   # => { available: n, next_available_at: Time | nil, bonus_collectable: true | false }
  module BankSummary
    def self.call(player, now: Time.current)
      {
        available: Pack.where(player_id: player.id).available(now).count,
        next_available_at: Pack.bank(player.id).where.not(available_at: ..now).minimum(:available_at),
        bonus_collectable: Catalog::PublishedSeason.call.present? &&
          !DailyBonusClaim.exists?(player_id: player.id, day: DailyBonusClaim.day_of(now))
      }
    end
  end
end
