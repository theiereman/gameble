module Game
  module Privileged
    def self.call(player, now: Time.current)
      return false if player.nil?

      ids(now:).include?(player.id)
    end

    def self.ids(now: Time.current)
      week = Fortune.week_of(now).ranked
      week.limit(FortuneIndex.privileged_count(week.count)).pluck(:player_id).to_set
    end
  end
end
