module Game
  class PublishWeeklyVerdictJob < ActiveJob::Base
    queue_as :default

    def perform
      now = Time.current
      winner = FortuneVerdict.winner(now:)
      return unless winner

      PublishWeeklyVerdict.new.call(player: winner.player, week_start: WeeklyGoal.week_start(now))
    end
  end
end
