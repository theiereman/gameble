module Game
  class DailyBonusClaim < ApplicationRecord
    self.table_name = "game_daily_bonus_claims"

    def self.day_of(now) = now.utc.to_date
  end
end
