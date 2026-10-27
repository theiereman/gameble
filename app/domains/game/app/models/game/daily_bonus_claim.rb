module Game
  # A player's daily bonus for one UTC day (CAP-16, AD-9): the bonus pack it
  # granted. One row per player and day, unique in the database, so a second
  # collection the same day is impossible whatever the client does.
  #
  # Written only through Game::CollectDailyBonus (AD-3).
  class DailyBonusClaim < ApplicationRecord
    self.table_name = "game_daily_bonus_claims"

    # The UTC day of a time (a day is a UTC day), whatever Time.zone says.
    def self.day_of(now) = now.utc.to_date
  end
end
