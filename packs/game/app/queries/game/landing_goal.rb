module Game
  module LandingGoal
    CACHE_LIFETIME = 1.minute

    def self.call(locale:, now: Time.current)
      Rails.cache.fetch([ "game/landing_goal", locale.to_s ], expires_in: CACHE_LIFETIME) { read(now) }
    end

    def self.read(now)
      goal = CurrentGoal.call(now:)
      participants = WeeklyContribution.where(week_start: WeeklyGoal.week_start(now)).where("openings + trades > 0").count
      { total: goal[:total], target: goal[:target], participants: }
    end

    private_class_method :read
  end
end
