module Game
  module BankSummary
    def self.reserve(player, now: Time.current)
      counts = Reserve.counts(player.id, now:)
      { available: counts.standard, special: counts.special, openable: counts.openable,
        reserve_full: Reserve.full?(counts.standard), next_available_at: BankSchedule.call(player, now:).first,
        next_special_kind: counts.next_special_kind }
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
