module Game
  class PublishWeeklyVerdictJob < ActiveJob::Base
    queue_as :default

    def perform
      now = Time.current
      winner = FortuneVerdict.winner(now:)
      PublishWeeklyVerdict.new.call(player: winner.player, week_start: WeeklyGoal.week_start(now)) if winner
      ActiveJob.perform_all_later(Fortune.of_period(:last_week, now).pluck(:player_id).map { GrantAchievementsJob.new(it) })
    end
  end
end
