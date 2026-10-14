module Game
  # What a player's chest shows (R9): their reserve, the packs they can open
  # now, of every kind (Game::Reserve), whether it is full, and when the next
  # pack of the bank comes (R4): the earliest future availability time among
  # the unopened regular packs, nil when every one is available or the
  # player has no bank: the first of Game::BankSchedule, the times the
  # opening exchange answers. Bonus and reward packs never move it.
  # `reserve_full`: the reserve holds Game::Reserve::FULL, so a collection
  # would be refused (AD-7); the same query as the operation's.
  #
  # `reserve` answers that part alone, in two queries: the top bar's chips,
  # the booster screen and the pack page need nothing more. `call` adds the
  # daily bonus, for the hub and the daily claim: `bonus_collectable`, a
  # season is published and the player has no daily bonus claim for the UTC
  # day of `now` (CAP-16), the same two checks as Game::CollectDailyBonus,
  # without loading the draw pool; `bonus_collected`, the player's claim for
  # that UTC day exists (the hub's panel then shows the countdown to
  # `next_bonus_at`, the next 00:00 UTC, when the day's bonus comes back).
  #
  #   Game::BankSummary.reserve(player)
  #   # => { available: n, reserve_full: true | false, next_available_at: Time | nil }
  #   Game::BankSummary.call(player)
  #   # => { available: n, reserve_full: true | false, next_available_at: Time | nil,
  #   #      bonus_collectable: true | false, bonus_collected: true | false,
  #   #      next_bonus_at: Time }
  #   Game::BankSummary.next_bonus_at   # => the next 00:00 UTC
  module BankSummary
    def self.reserve(player, now: Time.current)
      available = Reserve.count(player.id, now:)
      { available:, reserve_full: Reserve.full?(available), next_available_at: BankSchedule.call(player, now:).first }
    end

    def self.call(player, now: Time.current)
      day = DailyBonusClaim.day_of(now)
      collected = DailyBonusClaim.exists?(player_id: player.id, day:)
      reserve(player, now:).merge(
        bonus_collectable: !collected && Catalog::PublishedSeason.call.present?,
        bonus_collected: collected,
        next_bonus_at: next_bonus_at(now)
      )
    end

    def self.next_bonus_at(now = Time.current)
      DailyBonusClaim.day_of(now).next_day.in_time_zone("UTC")
    end
  end
end
