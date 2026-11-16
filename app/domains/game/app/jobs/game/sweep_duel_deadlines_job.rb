module Game
  class SweepDuelDeadlinesJob < ActiveJob::Base
    queue_as :duels

    def perform
      DuelsDue.call(Time.current).each do |token|
        DuelDeadlines.settle(token)
      rescue StandardError => error
        Rails.error.report(error, context: { duel_token: token })
      end
    end
  end
end
