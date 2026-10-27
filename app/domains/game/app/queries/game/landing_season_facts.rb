module Game
  module LandingSeasonFacts
    CACHE_LIFETIME = 1.minute

    def self.call(locale:, now: Time.current)
      Rails.cache.fetch([ "game/landing_season_facts", locale.to_s ], expires_in: CACHE_LIFETIME) { read(now.utc) }
    end

    def self.read(now)
      week_start = WeeklyGoal.week_start(now)
      since = week_start.in_time_zone("UTC")
      {
        season_number: Catalog::PublishedSeason.call&.number,
        players: WeeklyContribution.where(week_start:).where("openings > 0").count,
        packs: Pack.where(opened_at: now.beginning_of_day..now.end_of_day).count,
        discoveries: FirstDiscovery.where(discovered_at: since..).count
      }
    end

    private_class_method :read
  end
end
