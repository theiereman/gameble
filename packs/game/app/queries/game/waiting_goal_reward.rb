module Game
  # The week of a player's newest weekly goal reward whose pack is still
  # unopened, or nil (CAP-12; story 6.5): the hub's reward toast, keyed by
  # that week so a browser shows it once. One indexed read.
  #
  #   Game::WaitingGoalReward.call(player) # => Date | nil
  module WaitingGoalReward
    def self.call(player)
      GoalReward.where(player_id: player.id, pack_id: Pack.where(player_id: player.id).unopened.select(:id))
                .order(week_start: :desc).pick(:week_start)
    end
  end
end
